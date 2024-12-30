const std = @import("std");

const Version = struct { commit: []u8, version: []u8 };

const Forecast = struct { forecastType: []u8, forecastTimestamps: []struct { airTemperature: f32, conditionCode: []u8, forecastTimeUtc: []u8 } };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    readFileTest(allocator) catch |err| {
        std.debug.print("error while reading the file {any}\n", .{err});
        return;
    };

    const forecast = getWeatherForecast(allocator) catch |err| {
        std.debug.print("error while trying to get forecast {any}\n", .{err});
        return;
    };
    defer forecast.deinit();

    std.debug.print("forecast type: {s}\n", .{forecast.value.forecastType});
    for (forecast.value.forecastTimestamps) |timestamp| {
        std.debug.print("time={s}, temp={d}, code={s}\n", .{ timestamp.forecastTimeUtc, timestamp.airTemperature, timestamp.conditionCode });
    }
}

pub fn getWeatherForecast(alloc: std.mem.Allocator) !std.json.Parsed(Forecast) {
    var client = std.http.Client{ .allocator = alloc };
    defer client.deinit();

    const uri = try std.Uri.parse("https://api.meteo.lt/v1/places/vilnius/forecasts/long-term");

    var buf: [512]u8 = undefined;
    var req = try client.open(.GET, uri, .{
        .server_header_buffer = &buf,
    });
    defer req.deinit();

    try req.send();
    try req.finish();
    // Waits for a response from the server and parses any headers that are sent
    try req.wait();

    const content = try req.reader().readAllAlloc(alloc, 1000000);
    defer alloc.free(content);

    return try std.json.parseFromSlice(Forecast, alloc, content, .{ .ignore_unknown_fields = true });
}

pub fn readFileTest(alloc: std.mem.Allocator) !void {
    const file = try std.fs.cwd().openFile("test.txt", .{});
    defer file.close();

    const content = try file.reader().readAllAlloc(
        alloc,
        5000,
    );
    defer alloc.free(content);

    std.debug.print("File content: {s}\n", .{content});
}
