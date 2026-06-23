
// Dynamic Stackless Fibers ( Heap-allocated State Machine )
//  implementation with POSIX Sockets support

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
        get_fd: *const fn (ctx: *BaseFiber) std.posix.socket_t, // for cases like ssl-tls(https) wss, else -1 (when just number_cruncher like factorial example)
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
        .get_fd = getFdWrapper,
      };
    }; // end -- const Wrapper = struct {
    
    
    allocator: Allocator,
    fibers: std.ArrayList(*BaseFiber),
    poll_list: std.ArrayList(std.posix.pollfd),
    
    
    pub fn init(allocator: Allocator) Self {
      return .{
        .allocator = allocator,
        .fibers = std.ArrayList(*BaseFiber).init(allocator),
        .poll_list = std.ArrayList(std.posix.pollfd).init(allocator),
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
        try self.updatePollList();
        
        //const timeout: i32 = if (self.hasActiveSockets()) 1 else 0; // waiting for IO (if has sockets) - else just calculate our simple operations-calculations
        const timeout: i32 = if (self.poll_list.items.len > 0) 1 else 0; // waiting for IO (if has sockets) - else just calculate our simple operations-calculations
        _ = std.posix.poll(self.poll_list.items, timeout) catch 0;
        
        var i: usize = 0;
        while (i < self.fibers.items.len) {
          const fiber = self.fibers.items[i];
          
          if (self.isReady(fiber, i)) { // call if has_no sockets or when socket is ready
            const action = fiber.vtable.tick(fiber) catch .close_fiber;
            if (action == .close_fiber) {
              fiber.vtable.deinit(fiber);
              _ = self.fibers.swapRemove(i);
              continue;
            }
          }
          i += 1;
        }
        //std.Thread.yield() catch {}; // minimal delay
        try std.Thread.yield(); // minimal delay
      }
    }


    fn updatePollList(self: *Self) !void {
      self.poll_list.clearRetainingCapacity();
      for (self.fibers.items) |f| {
        const fd = f.vtable.get_fd(f);
        if (fd != -1) {
          try self.poll_list.append(.{ .fd = fd, .events = std.posix.POLL.IN, .revents = 0 });
        }
      }
    }


    //fn hasActiveSockets(self: *Self) bool {
    //  return self.poll_list.items.len > 0;
    //}


    fn isReady(self: *Self, f: *BaseFiber, _: usize) bool {
      const fd = f.vtable.get_fd(f);
      if (fd == -1) return true; // task without sockets - always ready
      for (self.poll_list.items) |pfd| {
        if (pfd.fd == fd) return pfd.revents != 0;
      }
      return false;
    }


    pub fn deinit(self: *Self) void {
      self.fibers.deinit();
      self.poll_list.deinit();
    }
  };
}

