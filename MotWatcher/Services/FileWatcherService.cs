using System.Collections.Concurrent;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using MotW.Shared.Services;
using MotW.Shared.Utils;
using MotWatcher.Models;

namespace MotWatcher.Services
{
    public class FileWatcherService : IDisposable
    {
        private readonly WatcherConfig _config;
        private readonly List<FileSystemWatcher> _watchers = new();
        private readonly ConcurrentDictionary<string, DateTime> _pendingFiles = new();
        private readonly CancellationTokenSource _cts = new();
        private Task? _processingTask;
        private bool _isRunning;

        public event EventHandler<FileProcessedEventArgs>? FileProcessed;

        public FileWatcherService(WatcherConfig config)
        {
            _config = config ?? throw new ArgumentNullException(nameof(config));
        }

        public void Start()
        {
            if (_isRunning)
            {
                Logger.Warn("FileWatcherService is already running.");
                return;
            }

            Logger.Info("Starting FileWatcherService...");
            _isRunning = true;

            // Create FileSystemWatcher for each enabled directory
            foreach (var dir in _config.WatchedDirectories.Where(d => d.Enabled))
            {
                if (!Directory.Exists(dir.Path))
                {
                    Logger.Warn($"Watched directory does not exist: {dir.Path}");
                    continue;
                }

                try
                {
                    var watcher = new FileSystemWatcher(dir.Path)
                    {
                        NotifyFilter = NotifyFilters.FileName | NotifyFilters.LastWrite | NotifyFilters.CreationTime,
                        IncludeSubdirectories = dir.IncludeSubdirectories,
                        EnableRaisingEvents = true
                    };

                    // Set filter based on file type filters
                    if (dir.FileTypeFilters.Count == 1 && dir.FileTypeFilters[0] == "*")
                    {
                        watcher.Filter = "*.*";
                    }
                    else
                    {
                        // FileSystemWatcher only supports one filter, so we'll filter in code
                        watcher.Filter = "*.*";
                    }

                    watcher.Created += OnFileCreated;
                    watcher.Changed += OnFileChanged;

                    _watchers.Add(watcher);
                    Logger.Info($"Watching: {dir.Path} (Subdirs: {dir.IncludeSubdirectories})");
                }
                catch (Exception ex)
                {
                    Logger.Error($"Failed to create watcher for {dir.Path}: {ex.Message}");
                }
            }

            // Start background processing task
            _processingTask = Task.Run(ProcessPendingFilesAsync, _cts.Token);
            Logger.Info($"FileWatcherService started with {_watchers.Count} active watchers.");
        }

        public void Stop()
        {
            if (!_isRunning)
                return;

            Logger.Info("Stopping FileWatcherService...");
            _isRunning = false;

            // Stop all watchers
            foreach (var watcher in _watchers)
            {
                watcher.EnableRaisingEvents = false;
                watcher.Created -= OnFileCreated;
                watcher.Changed -= OnFileChanged;
                watcher.Dispose();
            }
            _watchers.Clear();

            // Cancel processing task
            _cts.Cancel();
            _processingTask?.Wait(TimeSpan.FromSeconds(5));

            Logger.Info("FileWatcherService stopped.");
        }

        private void OnFileCreated(object sender, FileSystemEventArgs e)
        {
            QueueFileForProcessing(e.FullPath);
        }

        private void OnFileChanged(object sender, FileSystemEventArgs e)
        {
            // Also queue changed files in case they were downloaded/modified
            QueueFileForProcessing(e.FullPath);
        }

        private void QueueFileForProcessing(string filePath)
        {
            if (!File.Exists(filePath))
                return;

            // Check if file matches any watched directory's filters
            var matchingDir = GetMatchingWatchedDirectory(filePath);
            if (matchingDir == null)
                return;

            // Apply file type filter
            if (!MatchesFileTypeFilter(filePath, matchingDir))
                return;

            // Add to pending queue with current time (for debouncing)
            _pendingFiles[filePath] = DateTime.UtcNow;
            Logger.Info($"Queued for processing: {Path.GetFileName(filePath)}");
        }

        private WatchedDirectory? GetMatchingWatchedDirectory(string filePath)
        {
            foreach (var dir in _config.WatchedDirectories.Where(d => d.Enabled))
            {
                if (dir.IncludeSubdirectories)
                {
                    if (filePath.StartsWith(dir.Path, StringComparison.OrdinalIgnoreCase))
                        return dir;
                }
                else
                {
                    if (Path.GetDirectoryName(filePath)?.Equals(dir.Path, StringComparison.OrdinalIgnoreCase) == true)
                        return dir;
                }
            }
            return null;
        }

        private bool MatchesFileTypeFilter(string filePath, WatchedDirectory dir)
        {
            if (dir.FileTypeFilters.Contains("*"))
                return true;

            var extension = Path.GetExtension(filePath).ToLowerInvariant();
            return dir.FileTypeFilters.Any(filter =>
                filter.Equals(extension, StringComparison.OrdinalIgnoreCase) ||
                filter.Equals("*" + extension, StringComparison.OrdinalIgnoreCase));
        }

        private async Task ProcessPendingFilesAsync()
        {
            while (!_cts.Token.IsCancellationRequested)
            {
                try
                {
                    await Task.Delay(_config.DebounceDelayMs, _cts.Token);

                    var now = DateTime.UtcNow;
                    var filesToProcess = _pendingFiles
                        .Where(kvp => (now - kvp.Value).TotalMilliseconds >= _config.DebounceDelayMs)
                        .Select(kvp => kvp.Key)
                        .ToList();

                    foreach (var filePath in filesToProcess)
                    {
                        _pendingFiles.TryRemove(filePath, out _);
                        await ProcessFileAsync(filePath);
                    }
                }
                catch (OperationCanceledException)
                {
                    break;
                }
                catch (Exception ex)
                {
                    Logger.Error($"Error in processing loop: {ex.Message}");
                }
            }
        }

        private async Task ProcessFileAsync(string filePath)
        {
            if (!File.Exists(filePath))
            {
                Logger.Info($"File no longer exists, skipping: {filePath}");
                return;
            }

            var matchingDir = GetMatchingWatchedDirectory(filePath);
            if (matchingDir == null)
                return;

            await Task.Run(() =>
            {
                try
                {
                    // Check if file has MotW
                    if (!MotWService.HasMotW(filePath))
                    {
                        Logger.Info($"No MotW detected, skipping: {Path.GetFileName(filePath)}");
                        return;
                    }

                    // Check Zone ID threshold if configured
                    if (matchingDir.MinZoneId.HasValue)
                    {
                        var zoneId = GetZoneId(filePath);
                        if (!zoneId.HasValue || zoneId.Value < matchingDir.MinZoneId.Value)
                        {
                            Logger.Info($"Zone ID {zoneId} below threshold {matchingDir.MinZoneId}, skipping: {Path.GetFileName(filePath)}");
                            return;
                        }
                    }

                    // Remove MotW
                    var success = MotWService.Unblock(filePath, out var error);

                    if (success)
                    {
                        Logger.Info($"Successfully unblocked: {filePath}");
                        FileProcessed?.Invoke(this, new FileProcessedEventArgs
                        {
                            FilePath = filePath,
                            Success = true,
                            Message = "MotW removed successfully"
                        });
                    }
                    else
                    {
                        Logger.Error($"Failed to unblock {filePath}: {error}");
                        FileProcessed?.Invoke(this, new FileProcessedEventArgs
                        {
                            FilePath = filePath,
                            Success = false,
                            Message = error ?? "Unknown error"
                        });
                    }
                }
                catch (Exception ex)
                {
                    Logger.Error($"Error processing {filePath}: {ex.Message}");
                    FileProcessed?.Invoke(this, new FileProcessedEventArgs
                    {
                        FilePath = filePath,
                        Success = false,
                        Message = ex.Message
                    });
                }
            });
        }

        private int? GetZoneId(string filePath)
        {
            try
            {
                var streamPath = filePath + ":Zone.Identifier";
                if (!File.Exists(streamPath))
                    return null;

                var content = File.ReadAllText(streamPath);
                var lines = content.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
                var zoneLine = lines.FirstOrDefault(l => l.StartsWith("ZoneId=", StringComparison.OrdinalIgnoreCase));

                if (zoneLine != null && int.TryParse(zoneLine.Substring(7), out var zoneId))
                    return zoneId;
            }
            catch
            {
                // Ignore errors reading zone ID
            }

            return null;
        }

        public void Dispose()
        {
            Stop();
            _cts.Dispose();
        }
    }

    public class FileProcessedEventArgs : EventArgs
    {
        public string FilePath { get; set; } = string.Empty;
        public bool Success { get; set; }
        public string Message { get; set; } = string.Empty;
    }
}
