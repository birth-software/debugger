const Debugger = @This();

const std = @import("std");
const zgui = @import("zgui");

const Allocator = std.mem.Allocator;
const log = std.log;
const ModuleDebugInfo = std.debug.ModuleDebugInfo;

const PID = std.os.pid_t;

const Ptrace = @import("ptrace.zig").Ptrace;

debug_info: ModuleDebugInfo,
section_array: std.dwarf.DwarfInfo.SectionArray,
pid: PID,

pub fn init(allocator: Allocator, executable_relative_path: []const u8, pid: PID) !*Debugger {
    const debugger = try allocator.create(Debugger);
    var section_array: std.dwarf.DwarfInfo.SectionArray = std.dwarf.DwarfInfo.null_section_array;
    const debug_info = try std.debug.readElfDebugInfo(allocator, executable_relative_path, null, null, &section_array, null);
    debugger.* = .{
        .debug_info = debug_info,
        .section_array = section_array,
        .pid = pid,
    };

    std.time.sleep(1000000);

    try debugger.continueExecution();
    return debugger;
}

pub fn continueExecution(debugger: *const Debugger) !void {
    try Ptrace(.cont).request(debugger.pid);
    const wait_pid_result = std.os.waitpid(debugger.pid, 0);
    _ = wait_pid_result;
}

pub fn frame(debugger: *Debugger) void {
    _ = debugger;
}

pub fn deinit(debugger: *Debugger, allocator: Allocator) void {
    defer allocator.destroy(debugger);
    debugger.debug_info.deinit(allocator);
}
