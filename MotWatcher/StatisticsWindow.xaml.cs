using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Windows;
using MotW.Shared.Models;
using MotW.Shared.Services;

namespace MotWatcher;

public partial class StatisticsWindow : Window
{
    private readonly WatcherStatistics _statistics;
    private const long KB = 1024;
    private const long MB = KB * 1024;
    private const long GB = MB * 1024;

    public StatisticsWindow(WatcherStatistics statistics)
    {
        InitializeComponent();
        _statistics = statistics ?? throw new ArgumentNullException(nameof(statistics));
        LoadStatistics();
    }

    private void LoadStatistics()
    {
        // Overall Statistics
        TotalFilesText.Text = _statistics.TotalFilesProcessed.ToString("N0");
        TotalBytesText.Text = FormatBytes(_statistics.TotalBytesProcessed);

        FirstRunText.Text = _statistics.FirstRunDate == DateTime.MinValue
            ? "Never"
            : _statistics.FirstRunDate.ToLocalTime().ToString("g");

        LastProcessedText.Text = _statistics.LastProcessedDate == DateTime.MinValue
            ? "Never"
            : _statistics.LastProcessedDate.ToLocalTime().ToString("g");

        // Zone Statistics
        var zoneStats = _statistics.FilesByZoneId
            .OrderBy(kvp => kvp.Key)
            .Select(kvp => new
            {
                Zone = GetZoneName(kvp.Key),
                Count = kvp.Value
            })
            .ToList();
        ZoneStatsListView.ItemsSource = zoneStats;

        // Extension Statistics (Top 10)
        var totalFiles = _statistics.TotalFilesProcessed;
        var extensionStats = _statistics.FilesByExtension
            .OrderByDescending(kvp => kvp.Value)
            .Take(10)
            .Select(kvp => new
            {
                Extension = kvp.Key,
                Count = kvp.Value,
                Percentage = totalFiles > 0
                    ? $"{(kvp.Value * 100.0 / totalFiles):F1}%"
                    : "0%"
            })
            .ToList();
        ExtensionStatsListView.ItemsSource = extensionStats;

        // Daily Statistics (Last 7 Days)
        var dailyStats = _statistics.DailyHistory
            .OrderByDescending(d => d.Date)
            .Take(7)
            .OrderBy(d => d.Date)
            .Select(d => new
            {
                Date = d.Date.ToLocalTime().ToString("ddd, MMM dd"),
                Files = d.FilesProcessed.ToString("N0"),
                Data = FormatBytes(d.BytesProcessed)
            })
            .ToList();
        DailyStatsListView.ItemsSource = dailyStats;
    }

    private static string GetZoneName(int zoneId)
    {
        return zoneId switch
        {
            0 => "Zone 0 (Local Machine)",
            1 => "Zone 1 (Local Intranet)",
            2 => "Zone 2 (Trusted Sites)",
            3 => "Zone 3 (Internet)",
            4 => "Zone 4 (Restricted Sites)",
            _ => $"Zone {zoneId} (Unknown)"
        };
    }

    private static string FormatBytes(long bytes)
    {
        if (bytes == 0)
            return "0 B";

        if (bytes >= GB)
            return $"{bytes / (double)GB:F2} GB";

        if (bytes >= MB)
            return $"{bytes / (double)MB:F2} MB";

        if (bytes >= KB)
            return $"{bytes / (double)KB:F2} KB";

        return $"{bytes} B";
    }

    private void Reset_Click(object sender, RoutedEventArgs e)
    {
        var result = System.Windows.MessageBox.Show(
            "Are you sure you want to reset all statistics? This cannot be undone.",
            "Confirm Reset",
            MessageBoxButton.YesNo,
            MessageBoxImage.Warning);

        if (result == MessageBoxResult.Yes)
        {
            StatisticsService.Reset(_statistics);
            LoadStatistics();
            System.Windows.MessageBox.Show(
                "Statistics have been reset.",
                "Reset Complete",
                MessageBoxButton.OK,
                MessageBoxImage.Information);
        }
    }

    private void Close_Click(object sender, RoutedEventArgs e)
    {
        Close();
    }
}
