using System.Collections.ObjectModel;

namespace MotWatcher.Models
{
    public class WatcherConfig
    {
        public bool AutoStart { get; set; } = false;
        public bool StartWatchingOnLaunch { get; set; } = false;
        public bool NotifyOnProcess { get; set; } = true;
        public int DebounceDelayMs { get; set; } = 2000;
        public ObservableCollection<WatchedDirectory> WatchedDirectories { get; set; } = new();
    }

    public class WatchedDirectory
    {
        public string Path { get; set; } = string.Empty;
        public bool Enabled { get; set; } = true;
        public bool IncludeSubdirectories { get; set; } = false;
        public ObservableCollection<string> FileTypeFilters { get; set; } = new() { "*" };
        public int? MinZoneId { get; set; } = 3; // null = any, 3 = Internet, 2 = Trusted, 1 = Intranet
    }
}
