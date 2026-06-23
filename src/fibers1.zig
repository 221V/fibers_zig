
// Dynamic Stackless Fibers ( Heap-allocated State Machine )
//  implementation without POSIX Sockets support - do not spend a bit more RAM when that really no needs (see fibers2.zig for version with POSIX Sockets)

const std = @import("std");

const Allocator = std.mem.Allocator;


pub const FiberAction = enum {
  continue_loop,
  close_fiber,
};


pub const BaseFiber = struct {
    vtable: *const VTable,

    pub const VTable = struct {
        tick: *const fn (ctx: *BaseFiber) anyerror!FiberAction,
        deinit: *const fn (ctx: *BaseFiber) void,
    };
};


pub fn FiberManager(comptime T: type) type {
  return struct {
    const Self = @This();
    
    const Wrapper = struct {
      base: BaseFiber,
      data: T,
      allocator: Allocator,
      
      fn tickWrapper(base: *BaseFiber) anyerror!FiberAction {
        const self: *Wrapper = @alignCast(@fieldParentPtr("base", base));
        return self.data.tick();
      }
      
      fn deinitWrapper(base: *BaseFiber) void {
        const self: *Wrapper = @alignCast(@fieldParentPtr("base", base));
        self.data.deinit();
        const alloc = self.allocator;
        alloc.destroy(self);
      }
      
      fn getFdWrapper(base: *BaseFiber) std.posix.socket_t {
        const self: *Wrapper = @alignCast(@fieldParentPtr("base", base));
        if (@hasField(T, "fd")) return self.data.fd;
        return -1;
      }
      
      const vtable = BaseFiber.VTable{
        .tick = tickWrapper,
        .deinit = deinitWrapper,
      };
    }; // end -- const Wrapper = struct {
    
    
    allocator: Allocator,
    fibers: std.ArrayList(*BaseFiber),
    
    
    pub fn init(allocator: Allocator) Self {
      return .{
        .allocator = allocator,
        .fibers = std.ArrayList(*BaseFiber).init(allocator),
      };
    }

    pub fn spawn(self: *Self, data: T) !void {
      const wrapper = try self.allocator.create(Wrapper);
      wrapper.* = .{
        .base = .{ .vtable = &Wrapper.vtable },
        .data = data,
        .allocator = self.allocator,
      };
      try self.fibers.append(&wrapper.base);
    }

    pub fn run(self: *Self) !void {
      while (self.fibers.items.len > 0) {
        var i: usize = 0;
        while (i < self.fibers.items.len) {
          const fiber = self.fibers.items[i];
          const action = fiber.vtable.tick(fiber) catch .close_fiber;
          if (action == .close_fiber) {
            fiber.vtable.deinit(fiber);
            _ = self.fibers.swapRemove(i);
            continue;
          }
          i += 1;
        }
        //std.Thread.yield() catch {}; // minimal delay
        try std.Thread.yield(); // minimal delay
      }
    }

    pub fn deinit(self: *Self) void {
      self.fibers.deinit();
    }
  };
}

