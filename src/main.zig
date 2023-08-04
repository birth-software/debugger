const std = @import("std");
const zgui = @import("zgui");
const zglfw = @import("zglfw");
const zgpu = @import("zgpu");

const log = std.log;

const Debugger = @import("Debugger.zig");
const Ptrace = @import("ptrace.zig").Ptrace;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const debugger_arguments = try std.process.argsAlloc(allocator);
    const executable = if (false) "./main" else debugger_arguments[1];

    const pid = try std.os.fork();

    if (pid != 0) {
        var debugger = try Debugger.init(allocator, executable, pid);
        zglfw.init() catch {
            std.log.err("Failed to initialize GLFW library.", .{});
            return;
        };

        zgui.init(allocator);

        const initial_width = 800;
        const initial_height = 600;

        const window = zglfw.Window.create(initial_width, initial_height, "Birth debugger", null) catch {
            std.log.err("Failed to create demo window.", .{});
            return;
        };

        const gctx = try zgpu.GraphicsContext.create(allocator, window, .{});

        _ = zgui.io.addFontFromFile("/usr/share/fonts/TTF" ++ "/" ++ "FiraCode-Regular.ttf", 18.0);

        zgui.backend.init(
            window,
            gctx.device,
            @intFromEnum(zgpu.GraphicsContext.swapchain_format),
        );

        while (!window.shouldClose()) {
            zglfw.pollEvents();

            zgui.backend.newFrame(gctx.swapchain_descriptor.width, gctx.swapchain_descriptor.height);

            if (zgui.button("Continue", .{})) {
                try debugger.continueExecution();
            }

            const swapchain_texv = gctx.swapchain.getCurrentTextureView();
            defer swapchain_texv.release();

            const commands = commands: {
                const encoder = gctx.device.createCommandEncoder(null);
                defer encoder.release();

                // Gui pass.
                {
                    const pass = zgpu.beginRenderPassSimple(encoder, .load, swapchain_texv, null, null, null);
                    defer zgpu.endReleasePass(pass);
                    zgui.backend.draw(pass);
                }

                break :commands encoder.finish(null);
            };
            defer commands.release();

            gctx.submit(&.{commands});
            _ = gctx.present();
        }

        zgui.backend.deinit();
        zgui.plot.deinit();
        zgui.deinit();
        gctx.destroy(allocator);
        window.destroy();
        zglfw.terminate();
        debugger.deinit(allocator);
        std.process.argsFree(allocator, debugger_arguments);
        _ = gpa.deinit();
    } else {
        const arguments = &[_:null]?[*:0]const u8{executable};
        try Ptrace(.traceme).request();
        switch (std.os.execveZ(arguments[0].?, arguments, std.c.environ)) {
            else => |err| log.err("Error happened: {}", .{err}),
        }
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
