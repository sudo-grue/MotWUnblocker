using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;
using Microsoft.Win32;
using MotW.Shared.Services;
using MotW.Shared.Utils;
using MotWasher.Models;

namespace MotWasher
{
    public partial class MainWindow : Window
    {
        private readonly ObservableCollection<FileEntry> _files = new();
        private bool _isProcessing;

        public MainWindow()
        {
            InitializeComponent();
            DataContext = _files;
            Logger.Info("Application started.");

            PreviewKeyDown += MainWindow_PreviewKeyDown;
        }

        private void MainWindow_PreviewKeyDown(object sender, KeyEventArgs e)
        {
            if (_isProcessing)
                return;

            if (e.Key == Key.O && Keyboard.Modifiers == ModifierKeys.Control)
            {
                AddFiles_Click(this, new RoutedEventArgs());
                e.Handled = true;
            }
            else if (e.Key == Key.L && Keyboard.Modifiers == ModifierKeys.Control)
            {
                ClearAll_Click(this, new RoutedEventArgs());
                e.Handled = true;
            }
            else if (e.Key == Key.F5)
            {
                Refresh_Click(this, new RoutedEventArgs());
                e.Handled = true;
            }
            else if (e.Key == Key.W && Keyboard.Modifiers == ModifierKeys.Control)
            {
                WashFiles_Click(this, new RoutedEventArgs());
                e.Handled = true;
            }
        }

        private void AddFiles_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new OpenFileDialog
            {
                Title = "Select files",
                CheckFileExists = true,
                Multiselect = true,
                Filter = "All files (*.*)|*.*"
            };
            if (dlg.ShowDialog() == true)
            {
                AddFiles(dlg.FileNames);
            }
        }


        private void ClearAll_Click(object sender, RoutedEventArgs e)
        {
            if (_files.Count == 0)
            {
                SetStatus("No files to clear.");
                return;
            }

            var count = _files.Count;
            _files.Clear();
            SetStatus($"Cleared {count} file(s).");
            Logger.Info($"Cleared all files from list ({count} files)");
        }

        private async void Refresh_Click(object sender, RoutedEventArgs e)
        {
            if (_isProcessing)
                return;

            SetProcessingState(true);
            SetStatus("Refreshing zones...");

            var filesToRefresh = _files.ToList();

            await Task.Run(() =>
            {
                foreach (var f in filesToRefresh)
                {
                    var zoneId = MotWService.GetZoneId(f.FullPath);
                    Dispatcher.Invoke(() =>
                    {
                        f.HasMotW = zoneId.HasValue;
                        f.CurrentZoneId = zoneId;
                        f.NextZoneId = CalculateNextZone(zoneId);
                    });
                }
            });

            SetStatus($"Zones refreshed for {filesToRefresh.Count} file(s).");
            SetProcessingState(false);
        }

        private async void WashFiles_Click(object sender, RoutedEventArgs e)
        {
            if (_isProcessing)
                return;

            if (_files.Count == 0)
            {
                SetStatus("No files to wash. Drop files here or click Add Files.");
                return;
            }

            SetProcessingState(true);

            int washed = 0, clean = 0, removed = 0, failed = 0;
            var filesToProcess = _files.ToList();

            await Task.Run(() =>
            {
                foreach (var file in filesToProcess)
                {
                    try
                    {
                        var wasZone = MotWService.GetZoneId(file.FullPath);

                        if (MotWService.ReassignProgressive(file.FullPath, out var error))
                        {
                            var newZone = MotWService.GetZoneId(file.FullPath);

                            Dispatcher.Invoke(() =>
                            {
                                file.HasMotW = newZone.HasValue;
                                file.CurrentZoneId = newZone;
                                file.NextZoneId = CalculateNextZone(newZone);
                            });

                            if (!wasZone.HasValue)
                            {
                                clean++;
                            }
                            else if (!newZone.HasValue)
                            {
                                removed++;
                                Logger.Info($"Progressive wash removed MotW (was Zone {wasZone}): {file.FullPath}");
                            }
                            else
                            {
                                washed++;
                                Logger.Info($"Progressive wash {file.FullPath}: Zone {wasZone} → Zone {newZone}");
                            }
                        }
                        else
                        {
                            failed++;
                            Logger.Error($"Failed to wash {file.FullPath}: {error}");
                        }
                    }
                    catch (Exception ex)
                    {
                        failed++;
                        Logger.Error($"Error washing {file.FullPath}: {ex.Message}");
                    }
                }
            });

            // Clear list after washing to encourage re-drop for next wash
            _files.Clear();

            var statusParts = new List<string>();
            if (washed > 0)
                statusParts.Add($"{washed} washed");
            if (removed > 0)
                statusParts.Add($"{removed} MotW removed");
            if (clean > 0)
                statusParts.Add($"{clean} already clean");
            if (failed > 0)
                statusParts.Add($"{failed} failed");

            SetStatus($"Wash complete! {string.Join(", ", statusParts)}. Drop files again to wash further.");
            SetProcessingState(false);
        }

        private int? CalculateNextZone(int? currentZone)
        {
            if (!currentZone.HasValue)
                return null;
            if (currentZone.Value <= 0)
                return null; // No further washing possible
            return currentZone.Value - 1;
        }

        private void SetProcessingState(bool isProcessing)
        {
            _isProcessing = isProcessing;
            Mouse.OverrideCursor = isProcessing ? Cursors.Wait : null;

            foreach (var button in Toolbar.Items.OfType<System.Windows.Controls.Button>())
            {
                button.IsEnabled = !isProcessing;
            }
        }

        private void OpenLogFolder_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                var folder = Logger.LogFolder;
                Directory.CreateDirectory(folder);
                System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                {
                    FileName = folder,
                    UseShellExecute = true
                });
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, "Unable to open log folder: " + ex.Message, "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void AddFiles(string[] paths)
        {
            int added = 0, skipped = 0;
            foreach (var p in paths.Distinct())
            {
                try
                {
                    if (!File.Exists(p))
                    { skipped++; continue; }
                    if (_files.Any(f => string.Equals(f.FullPath, p, StringComparison.OrdinalIgnoreCase)))
                    {
                        skipped++;
                        continue;
                    }
                    var fi = new FileInfo(p);
                    var zoneId = MotWService.GetZoneId(fi.FullName);
                    var entry = new FileEntry(
                        fullPath: fi.FullName,
                        name: fi.Name,
                        extension: fi.Extension,
                        sizeBytes: fi.Length,
                        modifiedUtc: fi.LastWriteTimeUtc,
                        hasMotw: zoneId.HasValue
                    );
                    entry.CurrentZoneId = zoneId;
                    entry.NextZoneId = CalculateNextZone(zoneId);
                    _files.Add(entry);
                    added++;
                }
                catch (Exception ex)
                {
                    Logger.Error($"Add file failed: {p} :: {ex.Message}");
                    skipped++;
                }
            }
            SetStatus($"Added {added}, skipped {skipped}.");
        }

        private void Window_Drop(object sender, DragEventArgs e)
        {
            if (e.Data.GetDataPresent(DataFormats.FileDrop))
            {
                var paths = (string[])e.Data.GetData(DataFormats.FileDrop);
                AddFiles(paths);
            }
        }

        private void Window_DragOver(object sender, DragEventArgs e)
        {
            if (e.Data.GetDataPresent(DataFormats.FileDrop))
            {
                e.Effects = DragDropEffects.Copy;
                e.Handled = true;
            }
        }

        private void SetStatus(string text)
        {
            StatusText.Text = text;
        }
    }
}
