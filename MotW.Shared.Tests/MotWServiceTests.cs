using MotW.Shared.Services;

namespace MotW.Shared.Tests;

public class MotWServiceTests : IDisposable
{
    private readonly List<string> _testFiles = new();

    private string CreateTestFile()
    {
        var path = Path.GetTempFileName();
        _testFiles.Add(path);
        File.WriteAllText(path, "Test content");
        return path;
    }

    private void SetZone(string path, int zoneId)
    {
        var zoneStream = $"{path}:Zone.Identifier";
        File.WriteAllText(zoneStream, $"[ZoneTransfer]\nZoneId={zoneId}\nHostUrl=about:internet");
    }

    public void Dispose()
    {
        foreach (var file in _testFiles)
        {
            try
            {
                if (File.Exists(file))
                    File.Delete(file);

                var zoneStream = $"{file}:Zone.Identifier";
                if (File.Exists(zoneStream))
                    File.Delete(zoneStream);
            }
            catch
            {
            }
        }
    }

    [Fact]
    public void HasMotW_ReturnsFalse_WhenFileHasNoZone()
    {
        var testFile = CreateTestFile();
        Assert.False(MotWService.HasMotW(testFile));
    }

    [Fact]
    public void HasMotW_ReturnsTrue_WhenFileHasZone()
    {
        var testFile = CreateTestFile();
        SetZone(testFile, 3);
        Assert.True(MotWService.HasMotW(testFile));
    }

    [Fact]
    public void GetZoneId_ReturnsNull_WhenNoZone()
    {
        var testFile = CreateTestFile();
        Assert.Null(MotWService.GetZoneId(testFile));
    }

    [Fact]
    public void GetZoneId_ReturnsCorrectZone_WhenZoneExists()
    {
        var testFile = CreateTestFile();
        SetZone(testFile, 3);
        Assert.Equal(3, MotWService.GetZoneId(testFile));
    }

    [Fact]
    public void Block_AddsZone3_ByDefault()
    {
        var testFile = CreateTestFile();
        var result = MotWService.Block(testFile, out var error);

        Assert.True(result);
        Assert.Null(error);
        Assert.Equal(3, MotWService.GetZoneId(testFile));
    }

    [Fact]
    public void Block_AddsSpecifiedZone()
    {
        var testFile = CreateTestFile();
        var result = MotWService.Block(testFile, out var error, 2);

        Assert.True(result);
        Assert.Null(error);
        Assert.Equal(2, MotWService.GetZoneId(testFile));
    }

    [Fact]
    public void Block_RejectsInvalidZoneId()
    {
        var testFile = CreateTestFile();
        var result = MotWService.Block(testFile, out var error, 5);

        Assert.False(result);
        Assert.NotNull(error);
        Assert.Contains("Invalid zone ID", error);
    }

    [Fact]
    public void Unblock_RemovesZone()
    {
        var testFile = CreateTestFile();
        SetZone(testFile, 3);

        var result = MotWService.Unblock(testFile, out var error);

        Assert.True(result);
        Assert.Null(error);
        Assert.Null(MotWService.GetZoneId(testFile));
    }

    [Fact]
    public void Unblock_SucceedsOnCleanFile()
    {
        var testFile = CreateTestFile();

        var result = MotWService.Unblock(testFile, out var error);

        Assert.True(result);
        Assert.Null(error);
    }

    [Fact]
    public void Reassign_ChangesZone()
    {
        var testFile = CreateTestFile();
        SetZone(testFile, 3);

        var result = MotWService.Reassign(testFile, 2, out var error);

        Assert.True(result);
        Assert.Null(error);
        Assert.Equal(2, MotWService.GetZoneId(testFile));
    }

    [Fact]
    public void ReassignProgressive_MovesZone3To2()
    {
        var testFile = CreateTestFile();
        SetZone(testFile, 3);

        var result = MotWService.ReassignProgressive(testFile, out var error);

        Assert.True(result);
        Assert.Null(error);
        Assert.Equal(2, MotWService.GetZoneId(testFile));
    }

    [Fact]
    public void ReassignProgressive_MovesZone2To1()
    {
        var testFile = CreateTestFile();
        SetZone(testFile, 2);

        var result = MotWService.ReassignProgressive(testFile, out var error);

        Assert.True(result);
        Assert.Null(error);
        Assert.Equal(1, MotWService.GetZoneId(testFile));
    }

    [Fact]
    public void ReassignProgressive_MovesZone1To0()
    {
        var testFile = CreateTestFile();
        SetZone(testFile, 1);

        var result = MotWService.ReassignProgressive(testFile, out var error);

        Assert.True(result);
        Assert.Null(error);
        Assert.Equal(0, MotWService.GetZoneId(testFile));
    }

    [Fact]
    public void ReassignProgressive_RemovesZone0()
    {
        var testFile = CreateTestFile();
        SetZone(testFile, 0);

        var result = MotWService.ReassignProgressive(testFile, out var error);

        Assert.True(result);
        Assert.Null(error);
        Assert.Null(MotWService.GetZoneId(testFile));
    }

    [Fact]
    public void ReassignProgressive_SucceedsOnCleanFile()
    {
        var testFile = CreateTestFile();

        var result = MotWService.ReassignProgressive(testFile, out var error);

        Assert.True(result);
        Assert.NotNull(error);
        Assert.Contains("no MotW metadata", error);
        Assert.Null(MotWService.GetZoneId(testFile));
    }

    [Fact]
    public void ReassignProgressive_FullSequence_Zone3ToRemoved()
    {
        var testFile = CreateTestFile();
        SetZone(testFile, 3);

        Assert.True(MotWService.ReassignProgressive(testFile, out _));
        Assert.Equal(2, MotWService.GetZoneId(testFile));

        Assert.True(MotWService.ReassignProgressive(testFile, out _));
        Assert.Equal(1, MotWService.GetZoneId(testFile));

        Assert.True(MotWService.ReassignProgressive(testFile, out _));
        Assert.Equal(0, MotWService.GetZoneId(testFile));

        Assert.True(MotWService.ReassignProgressive(testFile, out _));
        Assert.Null(MotWService.GetZoneId(testFile));
    }

    [Fact]
    public void Block_FailsForEmptyPath()
    {
        var result = MotWService.Block("", out var error);

        Assert.False(result);
        Assert.NotNull(error);
        Assert.Contains("cannot be empty", error);
    }

    [Fact]
    public void Unblock_FailsForEmptyPath()
    {
        var result = MotWService.Unblock("", out var error);

        Assert.False(result);
        Assert.NotNull(error);
        Assert.Contains("cannot be empty", error);
    }

    [Fact]
    public void ReassignProgressive_FailsForEmptyPath()
    {
        var result = MotWService.ReassignProgressive("", out var error);

        Assert.False(result);
        Assert.NotNull(error);
        Assert.Contains("cannot be empty", error);
    }

    [Fact]
    public void Block_FailsForNonExistentFile()
    {
        var result = MotWService.Block("C:\\nonexistent\\file.txt", out var error);

        Assert.False(result);
        Assert.NotNull(error);
        Assert.Contains("does not exist", error);
    }

    // Zone 4 Protection Tests
    [Fact]
    public void ReassignProgressive_Zone4File_ReturnsFalseWithError()
    {
        var testFile = CreateTestFile();
        SetZone(testFile, 4);

        var result = MotWService.ReassignProgressive(testFile, out var error);

        Assert.False(result);
        Assert.NotNull(error);
        Assert.Contains("Zone 4", error);
        Assert.Contains("Restricted Sites", error);
        Assert.Equal(4, MotWService.GetZoneId(testFile)); // Zone should remain unchanged
    }

    [Fact]
    public void ReassignProgressive_Zone4File_DoesNotModifyFile()
    {
        var testFile = CreateTestFile();
        SetZone(testFile, 4);

        MotWService.ReassignProgressive(testFile, out _);

        // Verify zone is still 4
        Assert.Equal(4, MotWService.GetZoneId(testFile));
        Assert.True(MotWService.HasMotW(testFile));
    }

    [Fact]
    public void ReassignProgressive_Zone3File_SuccessfullyReassignsToZone2()
    {
        var testFile = CreateTestFile();
        SetZone(testFile, 3);

        var result = MotWService.ReassignProgressive(testFile, out var error);

        Assert.True(result);
        Assert.Null(error);
        Assert.Equal(2, MotWService.GetZoneId(testFile));
    }

    [Fact]
    public void Reassign_Zone4ToZone2_AllowsDirectReassignment()
    {
        var testFile = CreateTestFile();
        SetZone(testFile, 4);

        // Direct reassignment (not progressive) should work - for advanced users
        var result = MotWService.Reassign(testFile, 2, out var error);

        Assert.True(result);
        Assert.Null(error);
        Assert.Equal(2, MotWService.GetZoneId(testFile));
    }

    [Fact]
    public void GetZoneId_Zone4File_ReturnsCorrectZone()
    {
        var testFile = CreateTestFile();
        SetZone(testFile, 4);

        var zoneId = MotWService.GetZoneId(testFile);

        Assert.Equal(4, zoneId);
    }
}
