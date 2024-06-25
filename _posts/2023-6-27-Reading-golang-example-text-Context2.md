---
layout: post
title: "Golang example_text(2) : context ExampleWithDeadline"
author: "Peter"
categories: documentation
tags: [documentation,sample]
image: chill1.jpg
---

# Golang example_text : context ExampleWithDeadline

##  Foreword

从golang的example_text.go中自带的例子，可以最直接的了解到某一个包的用法和特性。但是我发现example_text.go中的例子，对于每一个初学者来说，直接看代码和注释，并没有办法直观的理解例子想要传达的包特性。

那么这篇文章我会从context这个包开始，和大家一起看懂他的这个example_text.go里所举的例子，以及他们各自想表达的context特性。



## package testing

那么首先打开GOROOT路径下的源文件

```
go/src/context/example_test.go
```



比如说我的就是以下路径：

```
/usr/local/share/go/src/context/example_test.go
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

### ExampleWithDeadline

$GOROOT/src/context/example_test.go

```golang
// This example passes a context with an arbitrary deadline to tell a blocking
// function that it should abandon its work as soon as it gets to it.
func ExampleWithDeadline() {
	d := time.Now().Add(shortDuration)
	ctx, cancel := context.WithDeadline(context.Background(), d)

	// Even though ctx will be expired, it is good practice to call its
	// cancellation function in any case. Failure to do so may keep the
	// context and its parent alive longer than necessary.
	defer cancel()

	select {
	case <-neverReady:
		fmt.Println("ready")
	case <-ctx.Done():
		fmt.Println(ctx.Err())
	}

	// Output:
	// context deadline exceeded
}
```



首先，d := time.Now().Add(shortDuration)定义了一个Time d, 也就是一个时间戳，那么这个时间戳可以看到是Now() 再加一个shortDuration（const shortDuration    = 1 * time.Millisecond）



ctx, cancel := context.WithDeadline(context.Background(), d) 初始化一个WithDeadline的ctx, 传入context.Background()，也就是一个空的context, 以及时间戳d



defer cancel()  意味着，在当前func（也就是 ExampleWithDeadline）即将执行完成时，会调用cancel方法。而cancel方法实际上会关闭ctx.Done()返回的channel



继续，select statement里有两个case, 

首先select statement用起来就像switch case一样，只是他的case都是channel操作（读或写channel），也就是说case后面跟的读或写操作可以被执行的话，该case语句就会被执行（假如多个case都能执行，select会选择任一个）

那么继续看这个select statement, 有两个case,第一个case, 试图读取一个channel neverReady, 如果完成一次读取，则打印ready

```golang
var neverReady = make(chan struct{}) // never closed
```

neverReady是一个buffer=0的 channel（buffer=0的 channel意味着，当一个goroutine往该channel**写**入数据时，他会一直等待，直到有任何goroutine从channel中**读**数据。那么相反，如果是一个buffer>0 的channel 当一个goroutine往里写数据时，只要buffer没有被填满，该goroutine都无需等待。 make sence, right？）



第二个是读ctx.Done()， ctx.Done()是Context接口的一个方法，返回的是一个channel，而这个channel往往会被Context手动或自动关闭，比如说如果是WithDeadline的话，cancel方法被执行时，该channel就会被关闭，或者超过时间戳Deadline时，也会被关闭。**而当一个channel被关闭时，这个channel总是可以被读**，那么这时对应的case就会被执行。并且打印ctx.Err()，这个方法会返回Done() channel被关闭的原因。



而第一个case, 由于读取neverReady，他在这个example里，既没有人去写，也不会被关闭，换句话说，读取neverReady的操作会一直等待，也就是说，这个case永远不会被执行，不会打印ready。



那么程序运行这里，会一直pend在这个select语句，因为两个case暂时都无法执行。



由于ExampleWithDeadline 方法pend在 select statement, 那么defer cancel也不会被执行。

一直等到设定的deadline时间戳时间到（也就是1 * time.Millisecond 后），我们的ctx自动cancel, Done()返回的channel被关闭，**而当一个channel被关闭时，这个channel总是可以被读**，select statement的第二个case被执行，打印ctx关闭原因，select 语句执行完毕.



ExampleWithDeadline方法结束，执行defer cancel的cancel func。由于ctx本身已经因为“deadline exceeded” 自动关闭，cancel方法执行和不执行都没有区别。所以你可以看到defer cancel()的注释

```golang
	// Even though ctx will be expired, it is good practice to call its
	// cancellation function in any case. Failure to do so may keep the
	// context and its parent alive longer than necessary.
	defer cancel()
```

这里只是希望展示一个好的practice, 但实际上for这个example, 不需要这句话也能正常退出，而我们可以注释掉这句话，再运行go test 来验证。那么你会发现，程序在编译时就会报错，这是go保护泄漏的措施～make sence

```
/usr/local/share/go/src/context/example_test.go:87:7: the cancel function returned by context.WithTimeout should be called, not discarded, to avoid a context leak
FAIL    context [build failed]
```





### ExampleWithTimeout

$GOROOT/src/context/example_test.go

```golang
// This example passes a context with a timeout to tell a blocking function that
// it should abandon its work after the timeout elapses.
func ExampleWithTimeout() {
	// Pass a context with a timeout to tell a blocking function that it
	// should abandon its work after the timeout elapses.
	ctx, cancel := context.WithTimeout(context.Background(), shortDuration)
	defer cancel()

	select {
	case <-neverReady:
		fmt.Println("ready")
	case <-ctx.Done():
		fmt.Println(ctx.Err()) // prints "context deadline exceeded"
	}

	// Output:
	// context deadline exceeded
}
```



而ExampleWithTimeout和ExampleWithDeadline的原理几乎一样，只是一个deadline一个timeout。而同样，cancel()方法也和上一个example的情况一样