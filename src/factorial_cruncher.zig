
// lets calculate factorial with fibers

const std = @import("std");
const print = std.debug.print;

const fibers = @import("fibers.zig");


const FactorialTask = struct {
    id: u32,
    n: u128,
    acc: u128,
    original_n: u128,

    pub fn deinit(self: *FactorialTask) void {
        print("Thread {d} | Fiber {d}: {d}! = {d}\n", .{
            std.Thread.getCurrentId(), self.id, self.original_n, self.acc
        });
    }

    pub fn tick(self: *FactorialTask) anyerror!fibers.FiberAction { // factorial_hepler(n, acc)
        var ops_in_this_tick: usize = 0;
        while (ops_in_this_tick < 2) : (ops_in_this_tick += 1) { // 2 operations per tick
            if (self.n == 0) return .close_fiber;
            
            self.acc *= self.n; // factorial_helper(n - 1, n * acc)
            self.n -= 1;
        }
        return .continue_loop;
    }
};


fn worker(thread_id: u32, count: u32) void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var manager = fibers.FiberManager(FactorialTask).init(allocator);
    defer manager.deinit();

    for (0..count) |i| {
        const n = @as(u128, 20 + (i % 15)); // calculate factorial of some random [20 .. 34] (upper value of u128)
        
        manager.spawn(.{
          //.id = @as(u32, @intCast(i)) + (thread_id * 1000), // 10 * 100 = 1000
          .id = @as(u32, @intCast(i)) + (thread_id * 3_000_000), // 3 * 1_000_000 = 3_000_000
          .n = n,
          .acc = 1, // init value like acc in factorial_helper(n, acc)
          .original_n = n,
        }) catch unreachable;
    }

    manager.run() catch |err| {
      print("FiberManager error: {}", .{err});
    };
}


pub fn main() !void {
    const thread_count = 3; // we got 4 threads at all = 1 main + this 3 additional // 10;
    const tasks_per_thread = 1_000_000; // 100;

    var threads: [thread_count]std.Thread = undefined;

    print("Run numbers cruncher: {d} cores, {d} tasks per core...\n", .{ thread_count, tasks_per_thread });

    for (0..thread_count) |i| {
      threads[i] = try std.Thread.spawn(.{}, worker, .{ @as(u32, @intCast(i)), tasks_per_thread });
    }

    for (threads) |t| t.join();
    print("All Done.\n", .{});
}

