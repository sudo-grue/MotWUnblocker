using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using MotW.Shared.Models;
using MotW.Shared.Utils;

namespace MotW.Shared.Services;

public static class StatisticsService
{
    private static readonly string StatsFilePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "MotW",
        "watcher-stats.json");

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    public static WatcherStatistics Load()
    {
        try
        {
            if (File.Exists(StatsFilePath))
            {
                var json = File.ReadAllText(StatsFilePath);
                var stats = JsonSerializer.Deserialize<WatcherStatistics>(json, JsonOptions);
                if (stats != null)
                {
                    // Clean up old daily history (keep last 30 days)
                    var cutoffDate = DateTime.UtcNow.Date.AddDays(-30);
                    stats.DailyHistory = stats.DailyHistory
                        .Where(d => d.Date >= cutoffDate)
                        .OrderBy(d => d.Date)
                        .ToList();

                    return stats;
                }
            }
        }
        catch (Exception ex)
        {
            Logger.Error($"Failed to load statistics: {ex.Message}");
        }

        return new WatcherStatistics();
    }

    public static void Save(WatcherStatistics stats)
    {
        try
        {
            var directory = Path.GetDirectoryName(StatsFilePath);
            if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }

            var json = JsonSerializer.Serialize(stats, JsonOptions);
            File.WriteAllText(StatsFilePath, json);
        }
        catch (Exception ex)
        {
            Logger.Error($"Failed to save statistics: {ex.Message}");
        }
    }

    public static void RecordFileProcessed(WatcherStatistics stats, string filePath, long fileSize, int zoneId)
    {
        ArgumentNullException.ThrowIfNull(stats);

        // Update totals
        stats.TotalFilesProcessed++;
        stats.TotalBytesProcessed += fileSize;
        stats.LastProcessedDate = DateTime.UtcNow;

        // Update zone ID stats - use TryGetValue to avoid double lookup
        if (!stats.FilesByZoneId.TryGetValue(zoneId, out long zoneCount))
        {
            zoneCount = 0;
        }
        stats.FilesByZoneId[zoneId] = zoneCount + 1;

        // Update file extension stats - use TryGetValue to avoid double lookup
        var extension = Path.GetExtension(filePath).ToUpperInvariant();
        if (string.IsNullOrEmpty(extension))
        {
            extension = "(no extension)";
        }
        if (!stats.FilesByExtension.TryGetValue(extension, out long extCount))
        {
            extCount = 0;
        }
        stats.FilesByExtension[extension] = extCount + 1;

        // Update daily history
        var today = DateTime.UtcNow.Date;
        var todayStats = stats.DailyHistory.FirstOrDefault(d => d.Date.Date == today);
        if (todayStats == null)
        {
            todayStats = new DailyStats { Date = today };
            stats.DailyHistory.Add(todayStats);
        }
        todayStats.FilesProcessed++;
        todayStats.BytesProcessed += fileSize;

        Save(stats);
    }

    public static void Reset(WatcherStatistics stats)
    {
        ArgumentNullException.ThrowIfNull(stats);

        stats.TotalFilesProcessed = 0;
        stats.TotalBytesProcessed = 0;
        stats.LastResetDate = DateTime.UtcNow;
        stats.FilesByZoneId.Clear();
        stats.FilesByExtension.Clear();
        stats.DailyHistory.Clear();
        Save(stats);
    }
}
