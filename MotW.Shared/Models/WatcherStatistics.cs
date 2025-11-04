using System;
using System.Collections.Generic;

namespace MotW.Shared.Models;

public class WatcherStatistics
{
    public long TotalFilesProcessed { get; set; }
    public long TotalBytesProcessed { get; set; }
    public DateTime FirstRunDate { get; set; } = DateTime.UtcNow;
    public DateTime LastResetDate { get; set; } = DateTime.UtcNow;
    public DateTime LastProcessedDate { get; set; }

    // Statistics by zone ID
    public Dictionary<int, long> FilesByZoneId { get; set; } = new();

    // Statistics by file extension
    public Dictionary<string, long> FilesByExtension { get; set; } = new();

    // Daily history (last 30 days)
    public List<DailyStats> DailyHistory { get; set; } = new();
}

public class DailyStats
{
    public DateTime Date { get; set; }
    public long FilesProcessed { get; set; }
    public long BytesProcessed { get; set; }
}
