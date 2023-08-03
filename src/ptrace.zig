const std = @import("std");
const PID = std.os.pid_t;

pub const Request = enum(u32) {
    /// Indicate that the process making this request should be traced.
    /// All signals received by this process can be intercepted by its
    /// parent, and its parent can use the other `ptrace' requests.
    traceme = 0,
    /// Return the word in the process's text space at address ADDR.
    peektext = 1,
    /// Return the word in the process's data space at address ADDR.
    peekdata = 2,
    /// Return the word in the process's user area at offset ADDR.
    peekuser = 3,
    /// Write the word DATA into the process's text space at address ADDR.
    poketext = 4,
    /// Write the word DATA into the process's data space at address ADDR.
    pokedata = 5,
    /// Write the word DATA into the process's user area at offset ADDR.
    pokeuser = 6,
    /// Continue the process.
    cont = 7,
    /// Kill the process.
    kill = 8,
    /// Single step the process.
    singlestep = 9,
    /// Get all general purpose registers used by a processes.
    getregs = 12,
    /// Set all general purpose registers used by a processes.
    setregs = 13,
    /// Get all floating point registers used by a processes.
    getfpregs = 14,
    /// Set all floating point registers used by a processes.
    setfpregs = 15,
    /// Attach to a process that is already running. */
    attach = 16,
    /// Detach from a process attached to with ATTACH.
    detach = 17,
    /// Get all extended floating point registers used by a processes.
    getfpxregs = 18,
    /// Set all extended floating point registers used by a processes.
    setfpxregs = 19,
    /// Continue and stop at the next entry to or return from syscall.
    syscall = 24,
    /// Get a TLS entry in the GDT.
    get_thread_area = 25,
    /// Change a TLS entry in the GDT.
    set_thread_area = 26,
    /// Access TLS data.
    arch_prctl = 30,
    /// Continue and stop at the next syscall, it will not be executed.
    sysemu = 31,
    /// Single step the process, the next syscall will not be executed.
    sysemu_singlestep = 32,
    /// Execute process until next taken branch.
    singleblock = 33,
    /// Set ptrace filter options.
    setoptions = 0x4200,
    /// Get last ptrace message.
    geteventmsg = 0x4201,
    /// Get siginfo for process.
    getsiginfo = 0x4202,
    /// Set new siginfo for process.
    setsiginfo = 0x4203,
    /// Get register content.
    getregset = 0x4204,
    /// Set register content.
    setregset = 0x4205,
    /// Like ATTACH, but do not force tracee to trap and do not affect
    /// signal or group stop state.
    seize = 0x4206,
    /// Trap seized tracee.
    interrupt = 0x4207,
    /// Wait for next group event.
    listen = 0x4208,
    /// Retrieve siginfo_t structures without removing signals from a queue.
    peeksiginfo = 0x4209,
    /// Get the mask of blocked signals.
    getsigmask = 0x420a,
    /// Change the mask of blocked signals.
    setsigmask = 0x420b,
    /// Get seccomp BPF filters.
    seccomp_get_filter = 0x420c,
    /// Get seccomp BPF filter metadata.
    seccomp_get_metadata = 0x420d,
    /// Get information about system call.
    get_syscall_info = 0x420e,
    /// Get rseq configuration information.
    get_rseq_configuration = 0x420f,
};

pub fn Ptrace(comptime req: Request) type {
    const req_integer = @intFromEnum(req);
    return switch (req) {
        .traceme => struct {
            pub fn request() !void {
                try std.os.ptrace(req_integer, 0, 0, 0);
                //try std.os.raise(std.os.SIG.STOP);
            }
        },
        .cont => struct {
            pub fn request(pid: PID) !void {
                try std.os.ptrace(req_integer, pid, 0, 0);
            }
        },
        else => @compileError("WTF"),
    };
}

// pub fn ptrace(
//     req: u32,
//     pid: pid_t,
//     addr: usize,
//     data: usize,
//     addr2: usize,
// ) usize {
//     std.os.ptrace
//         .linux => switch (errno(linux.ptrace(request, pid, addr, signal, 0))) {
//     std.os.linux.PTRACE.SINGLESTEP
// }
