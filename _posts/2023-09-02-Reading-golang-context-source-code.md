---
layout: post
title: "Golang example_text(3) : sync/context"
author: "Peter"
categories: documentation
tags: [documentation,sample]
image: chill1.jpg
---

# Golang example_text : sync ExampleWaitGroup



## Foreword

从golang的example_text.go中自带的例子，可以最直接的了解到某一个包的用法和特性。但是我发现example_text.go中的例子，对于每一个初学者来说，直接看代码和注释，并没有办法直观的理解例子想要传达的包特性。

那么这篇文章我会从context这个包开始，和大家一起看懂他的这个example_text.go里所举的例子，以及他们各自想表达的context特性。



## package testing

那么首先打开GOROOT路径下的源文件

```
go/src/sync/example_test.go
```



比如说我的就是以下路径：

```
/usr/local/share/go/src/sync/example_test.go
```



得益于golang自带的testing包，我们可以非常方便地编写单元测试，或者用来执行你自己的测试demo，而不需要借助任何外部依赖，

以至于，在我们阅读go的源码时，package路径下example_test.go里的用例都能被直接运行，这个是绝大部分其他语言都不具备的优势，意味着你可以很方便地调试。



你可以方便地使用 go test 命令行来执行测试用例，无论是你自己写的，还是我们今天想读的源码的测试用例



当你执行:

```shell
go test
```

go重新编译package, 然后查找当前目录下的所有_text 结尾的 go文件，



然后，xxx_test.go文件里，不同的测试方法需要follow不同的naming pattern

会有四种类型，test function，benchmark function，fuzz test 以及 Example function



Testing functions



A test function is one named TestXxx (where Xxx does not start with a lower case letter) and should have the signature,

```
func TestXxx(t *testing.T) { ... }
```

A benchmark function is one named BenchmarkXxx and should have the signature,

```
func BenchmarkXxx(b *testing.B) { ... }
```

A fuzz test is one named FuzzXxx and should have the signature,

```
func FuzzXxx(f *testing.F) { ... }
```

Example function

```
func ExamplePrintln() {
	Println("The output of\nthis example.")
	// Output: The output of
	// this example.
}
```



我们读example_test.go里的方法，主要都是 **Example function**  类型

那么大部分IDE都有对应的插件，让你方便的执行某个**特定**的 Testing functions ，如果你用命令行的话，大概会长这样：

```shell
go test --run=ExampleWithCancel 
```



## Example

### ExampleAfterFunc_cond

$GOROOT/src/sync/example_test.go

```golang
// This example fetches several URLs concurrently,
// using a WaitGroup to block until all the fetches are complete.
func ExampleWaitGroup() {
	var wg sync.WaitGroup
	var urls = []string{
		"http://www.golang.org/",
		"http://www.google.com/",
		"http://www.example.com/",
	}
	for _, url := range urls {
		// Increment the WaitGroup counter.
		wg.Add(1)
		// Launch a goroutine to fetch the URL.
		go func(url string) {
			// Decrement the counter when the goroutine completes.
			defer wg.Done()
			// Fetch the URL.
			http.Get(url)
		}(url)
	}
	// Wait for all HTTP fetches to complete.
	wg.Wait()
}
```



首先我们创建了一个WaitGroup， wg 

for 循环 range urls数组，那么在每个循环体里，wg.Add(1), 然后开启一个匿名func的goroutine，那么在该goroutine里发送一个http Get request, 完成访问后，调用wg.Done()



首先简单介绍一下WaitGroup的工作方式，我们可以理解为WaitGroup本身维护一个counter, wg.Add(1)相当于把counter加一，而wg.Done()相当于counter -1, 而wg.Wait()会一直pending, 知道counter = 0

当然，我们阅读源码会发现，要实现这个机制，WaitGroup本身相当复杂，但从使用者来看，我们暂时可以这么理解



那么for循环结束后，相当于开启了三个goroutine, 分别进行http 访问，同时我们此时的WaitGroup counter=3, 当我们调用wg.Wait()时，当前goroutine将会一直pending直到counter=0，而三个子goroutine会分别在完成http请求后，调用wg.Done(). 

因此，只有三个http请求都各自完成后，主goroutine才会继续。



这就是最常见的WaitGroup用法。



接下来我们看一下WaitGroup是如何实现跨goroutine的信号量调度的



### sync.WaitGroup

```golang
//A WaitGroup must not be copied after first use.

type WaitGroup struct {
	noCopy noCopy

	state atomic.Uint64 // high 32 bits are counter, low 32 bits are waiter count.
	sema  uint32
}
```



那么我们回头再看这个struct是怎么工作的，首先，我们已经清楚WaitGroup的工作方式，大致就是通过waitGroup结构维护的一个counter, 来控制一个或多个goroutine的等待，那么我们来看WaitGroup的Add function和 Wait function，是如何实现这一特性的



####  Add(delta int)

```golang
// Add adds delta, which may be negative, to the WaitGroup counter.
// If the counter becomes zero, all goroutines blocked on Wait are released.
// If the counter goes negative, Add panics.
//
// Note that calls with a positive delta that occur when the counter is zero
// must happen before a Wait. Calls with a negative delta, or calls with a
// positive delta that start when the counter is greater than zero, may happen
// at any time.
// Typically this means the calls to Add should execute before the statement
// creating the goroutine or other event to be waited for.
// If a WaitGroup is reused to wait for several independent sets of events,
// new Add calls must happen after all previous Wait calls have returned.
// See the WaitGroup example.
func (wg *WaitGroup) Add(delta int) {
	if race.Enabled {
		if delta < 0 {
			// Synchronize decrements with Wait.
			race.ReleaseMerge(unsafe.Pointer(wg))
		}
		race.Disable()
		defer race.Enable()
	}
	state := wg.state.Add(uint64(delta) << 32)
	v := int32(state >> 32)
	w := uint32(state)
	if race.Enabled && delta > 0 && v == int32(delta) {
		// The first increment must be synchronized with Wait.
		// Need to model this as a read, because there can be
		// several concurrent wg.counter transitions from 0.
		race.Read(unsafe.Pointer(&wg.sema))
	}
	if v < 0 {
		panic("sync: negative WaitGroup counter")
	}
	if w != 0 && delta > 0 && v == int32(delta) {
		panic("sync: WaitGroup misuse: Add called concurrently with Wait")
	}
	if v > 0 || w == 0 {
		return
	}
	// This goroutine has set counter to 0 when waiters > 0.
	// Now there can't be concurrent mutations of state:
	// - Adds must not happen concurrently with Wait,
	// - Wait does not increment waiters if it sees counter == 0.
	// Still do a cheap sanity check to detect WaitGroup misuse.
	if wg.state.Load() != state {
		panic("sync: WaitGroup misuse: Add called concurrently with Wait")
	}
	// Reset waiters count to 0.
	wg.state.Store(0)
	for ; w != 0; w-- {
		runtime_Semrelease(&wg.sema, false, 0)
	}
}
```



首先我们看到很多 race.Enabled 相关的判断，这个是golang自身的竞态检查机制，不影响我们理解WaitGroup的代码，我们直接忽略。

wg.state是一个atomic.Uint64 前32位作为counter ， 后32位作为waiter count,也就是等待的goroutine数目，所以

```
v := int32(state >> 32)
w := uint32(state)
```

v就是counter, w就是waiter count



下面的几个if条件就是我们Waitgroup机制的大部分内容，直接看代码会很绕，为了帮助我们理解代码，那么我们先声明几个前提：

从Add方法前的注释我们可以了解到WaitGroup的一些机制，大致如下：

1. Add方法可以加正数，也可以Add负数
2. 如果Add是正数，且当前counter等于0, 则这个Add一定要在Wait之前发生（这个很好理解，如果Wait先发生，那就相当于没东西wait, 因为counter为0）
3. Add负数或者Add正数但当前counter大于0，可以发生在任何时候
4. 如果一个WaitGroup被reuse to wait， 那么它之前的一次wait必须等待完成后，才执行新的Add call



那么我们继续看代码



if race.Enabled && delta > 0 && v == int32(delta) {   // 跳过



if v < 0  // panic,  counter不应该小于零，make sense



if w != 0 && delta > 0 && v == int32(delta) 则panic, 也就是说waiter count不为零，但是delta== v, 而且大于0,  

这违反了机制2 ，w!=0说明Wait方法被某个goroutine调用了，但是delta > 0 && v == int32(delta) ，也就是说调用Wait时 counter等于 0，说明“Add called concurrently with Wait“， 也就是说两个goroutine正在分别同时进行Wait和Add。为什么这个地方panic的时候说的是“Add called concurrently with Wait“， 同时进行？你会问，难道不是先wait了，然后再add,导致的吗？ 首先wait和Add方法不是原子操作，但里面对state的操作是原子的，然后，wait方法在调用时，如果发现counter等于0, 会直接正常return。所以，当我们在Add的时候，发现当前counter等于0, 但wait count不为0, 可以认为是“Add called concurrently with Wait“

因此panic, misuse



if v > 0 || w == 0 正常情况，加完delta后 counter 大于0，或者waiter等于0的情况，直接返回



这一步是又在做了一次低成本的检查，wg.state.Load()是原子操作，我们在Add方法内部再做一次check，

wg.state.Load() != state 说明 w 也就是waiter count 不等于0，则panic，

注意这里的check只是一次额外的查询，以上的所有机制，都并没有办法完全防止机制2的发生（原因很简单，Add和Wait都不是原子操作，他们中间的任何一步中间，都有可能发生state状态的改变），机制2需要由调用者来确保。



最后



#### Wait()

```golang
// Wait blocks until the WaitGroup counter is zero.
func (wg *WaitGroup) Wait() {
	if race.Enabled {
		race.Disable()
	}
	for {
		state := wg.state.Load()
		v := int32(state >> 32)
		w := uint32(state)
		if v == 0 {
			// Counter is 0, no need to wait.
			if race.Enabled {
				race.Enable()
				race.Acquire(unsafe.Pointer(wg))
			}
			return
		}
		// Increment waiters count.
		if wg.state.CompareAndSwap(state, state+1) {
			if race.Enabled && w == 0 {
				// Wait must be synchronized with the first Add.
				// Need to model this is as a write to race with the read in Add.
				// As a consequence, can do the write only for the first waiter,
				// otherwise concurrent Waits will race with each other.
				race.Write(unsafe.Pointer(&wg.sema))
			}
			runtime_Semacquire(&wg.sema)
			if wg.state.Load() != 0 {
				panic("sync: WaitGroup is reused before previous Wait has returned")
			}
			if race.Enabled {
				race.Enable()
				race.Acquire(unsafe.Pointer(wg))
			}
			return
		}
	}
}
```

