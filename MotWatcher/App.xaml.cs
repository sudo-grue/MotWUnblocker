using System.Drawing;
using System.Windows;
using System.Windows.Forms;
using MotW.Shared.Utils;
using MotWatcher.Services;
using Application = System.Windows.Application;

namespace MotWatcher;

/// <summary>
/// Interaction logic for App.xaml
/// </summary>
public partial class App : Application
{
    private NotifyIcon? _notifyIcon;
    private FileWatcherService? _watcherService;
    private Models.WatcherConfig? _config;

    private void Application_Startup(object sender, StartupEventArgs e)
    {
        Logger.Info("MotWatcher starting...");

        // Load configuration
        _config = ConfigService.Load();

        // Create system tray icon
        _notifyIcon = new NotifyIcon
        {
            Icon = SystemIcons.Shield, // Using built-in icon for now
            Visible = true,
            Text = "MotW Watcher - Not Running"
        };

        // Create context menu
        var contextMenu = new ContextMenuStrip();

        var startStopItem = new ToolStripMenuItem("Start Watching")
        {
            Name = "StartStop"
        };
        startStopItem.Click += StartStop_Click;
        contextMenu.Items.Add(startStopItem);

        contextMenu.Items.Add(new ToolStripSeparator());

        var settingsItem = new ToolStripMenuItem("Settings...");
        settingsItem.Click += Settings_Click;
        contextMenu.Items.Add(settingsItem);

        var openLogItem = new ToolStripMenuItem("Open Log Folder");
        openLogItem.Click += OpenLog_Click;
        contextMenu.Items.Add(openLogItem);

        contextMenu.Items.Add(new ToolStripSeparator());

        var exitItem = new ToolStripMenuItem("Exit");
        exitItem.Click += Exit_Click;
        contextMenu.Items.Add(exitItem);

        _notifyIcon.ContextMenuStrip = contextMenu;
        _notifyIcon.DoubleClick += NotifyIcon_DoubleClick;

        // Initialize watcher service
        _watcherService = new FileWatcherService(_config);
        _watcherService.FileProcessed += OnFileProcessed;

        // Auto-start watching if configured
        if (_config.StartWatchingOnLaunch)
        {
            StartWatching();
        }

        Logger.Info("MotWatcher initialized.");
    }

    private void StartStop_Click(object? sender, EventArgs e)
    {
        if (_watcherService == null || _notifyIcon == null || _notifyIcon.ContextMenuStrip == null)
            return;

        var menuItem = _notifyIcon.ContextMenuStrip.Items["StartStop"] as ToolStripMenuItem;
        if (menuItem == null)
            return;

        if (menuItem.Text == "Start Watching")
        {
            StartWatching();
        }
        else
        {
            StopWatching();
        }
    }

    private void StartWatching()
    {
        if (_watcherService == null || _notifyIcon == null || _notifyIcon.ContextMenuStrip == null)
            return;

        var menuItem = _notifyIcon.ContextMenuStrip.Items["StartStop"] as ToolStripMenuItem;
        if (menuItem != null)
        {
            _watcherService.Start();
            menuItem.Text = "Stop Watching";
            _notifyIcon.Text = "MotWatcher - Running";
            _notifyIcon.Icon = SystemIcons.Application;
            Logger.Info("Watcher service started.");
        }
    }

    private void StopWatching()
    {
        if (_watcherService == null || _notifyIcon == null || _notifyIcon.ContextMenuStrip == null)
            return;

        var menuItem = _notifyIcon.ContextMenuStrip.Items["StartStop"] as ToolStripMenuItem;
        if (menuItem != null)
        {
            _watcherService.Stop();
            menuItem.Text = "Start Watching";
            _notifyIcon.Text = "MotWatcher - Not Running";
            _notifyIcon.Icon = SystemIcons.Shield;
            Logger.Info("Watcher service stopped.");
        }
    }

    private void Settings_Click(object? sender, EventArgs e)
    {
        if (_config == null)
            return;

        var settingsWindow = new SettingsWindow(_config)
        {
            Owner = null
        };

        if (settingsWindow.ShowDialog() == true)
        {
            // Reload config
            _config = ConfigService.Load();

            // Restart watcher service if it was running
            if (_watcherService != null)
            {
                var wasRunning = _notifyIcon?.ContextMenuStrip?.Items["StartStop"] is ToolStripMenuItem item &&
                                 item.Text == "Stop Watching";

                if (wasRunning)
                {
                    StopWatching();
                    _watcherService = new FileWatcherService(_config);
                    _watcherService.FileProcessed += OnFileProcessed;
                    StartWatching();
                    Logger.Info("Watcher service restarted with new configuration.");
                }
                else
                {
                    // Just reinitialize without starting
                    _watcherService.Dispose();
                    _watcherService = new FileWatcherService(_config);
                    _watcherService.FileProcessed += OnFileProcessed;
                    Logger.Info("Watcher service reloaded with new configuration.");
                }
            }
        }
    }

    private void OpenLog_Click(object? sender, EventArgs e)
    {
        try
        {
            var folder = Logger.LogFolder;
            System.IO.Directory.CreateDirectory(folder);
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
            {
                FileName = folder,
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            Logger.Error($"Failed to open log folder: {ex.Message}");
            System.Windows.MessageBox.Show(
                $"Unable to open log folder: {ex.Message}",
                "Error",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
        }
    }

    private void Exit_Click(object? sender, EventArgs e)
    {
        Logger.Info("Exit requested by user.");
        Shutdown();
    }

    private void NotifyIcon_DoubleClick(object? sender, EventArgs e)
    {
        Settings_Click(sender, e);
    }

    private void OnFileProcessed(object? sender, FileProcessedEventArgs e)
    {
        if (_config?.NotifyOnProcess == true && _notifyIcon != null)
        {
            var fileName = System.IO.Path.GetFileName(e.FilePath);
            var title = e.Success ? "MotW Removed" : "Failed to Remove MotW";
            var message = e.Success
                ? $"Successfully unblocked: {fileName}"
                : $"Failed to unblock {fileName}: {e.Message}";

            _notifyIcon.ShowBalloonTip(
                3000,
                title,
                message,
                e.Success ? ToolTipIcon.Info : ToolTipIcon.Warning);
        }
    }

    private void Application_Exit(object sender, ExitEventArgs e)
    {
        Logger.Info("MotWatcher shutting down...");

        _watcherService?.Dispose();

        if (_notifyIcon != null)
        {
            _notifyIcon.Visible = false;
            _notifyIcon.Dispose();
        }

        Logger.Info("MotWatcher shutdown complete.");
    }
}

