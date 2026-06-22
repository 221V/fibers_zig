
// Dynamic Stackless Fibers ( Heap-allocated State Machine )

const std = @import("std");

pub const FiberAction = enum {
  continue_loop,
  close_fiber,
};


pub const BaseFiber = struct {
    fd: std.posix.socket_t = -1, // -1 for numbers cruncher
    vtable: *const VTable,

    pub const VTable = struct {
        tick: *const fn (ctx: *BaseFiber) anyerror!FiberAction,
        deinit: *const fn (ctx: *BaseFiber) void,
    };

    pub fn tick(self: *BaseFiber) !FiberAction {
        return self.vtable.tick(self);
    }

    pub fn deinit(self: *BaseFiber) void {
        self.vtable.deinit(self);
    }
};


pub const FiberManager = struct {
    allocator: std.mem.Allocator,
    compute_fibers: std.ArrayList(*BaseFiber),

    pub fn init(allocator: std.mem.Allocator) FiberManager {
        return .{
            .allocator = allocator,
            .compute_fibers = std.ArrayList(*BaseFiber).init(allocator),
        };
    }

    pub fn spawn(self: *FiberManager, fiber: *BaseFiber) !void {
        try self.compute_fibers.append(fiber);
    }

    pub fn run(self: *FiberManager) !void {
        while (self.compute_fibers.items.len > 0) {
            var i: usize = 0;
            while (i < self.compute_fibers.items.len) {
                const fiber = self.compute_fibers.items[i];
                const action = fiber.tick() catch .close_fiber;

                if (action == .close_fiber) {
                    fiber.deinit();
                    _ = self.compute_fibers.swapRemove(i);
                } else {
                    i += 1;
                }
            }
            //std.thread.yield() catch {}; // minimal delay
            try std.Thread.yield(); // minimal delay
        }
    }

    pub fn deinit(self: *FiberManager) void {
        self.compute_fibers.deinit();
    }
};

