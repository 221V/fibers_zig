# fibers_zig - Dynamic Stackless Fibers for Zig<br> ( Heap-allocated State Machine )

```
zig 0.14.1
tested on (l)ubuntu 22.04 LTS

zig build-exe ./src/factorial_cruncher.zig -O ReleaseFast -femit-bin=factorial_cruncher
./factorial_cruncher
```
there are two implementations - versions with and without POSIX Sockets support  
  
.  
  
**factorial_cruncher.zig** example uses **fibers1.zig** - implementation without POSIX Sockets support -  
do not spend a bit more RAM when that really no needs (see **fibers2.zig** for version with POSIX Sockets)  

