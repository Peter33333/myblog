---
layout: post
title: "Golang example_text(1) : context ExampleWithCancel"
author: "Peter"
categories: documentation
tags: [documentation,sample]
image: cool1.jpg
---

# Golang example_text : context ExampleWithCancel



## Foreword

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



## Examples

### ExampleWithCancel

$GOROOT/src/context/example_test.go

```golang
// This example demonstrates the use of a cancelable context to prevent a
// goroutine leak. By the end of the example function, the goroutine started
// by gen will return without leaking.
func ExampleWithCancel() {
	// gen generates integers in a separate goroutine and
	// sends them to the returned channel.
	// The callers of gen need to cancel the context once
	// they are done consuming generated integers not to leak
	// the internal goroutine started by gen.
	gen := func(ctx context.Context) <-chan int {
		dst := make(chan int)
		n := 1
		go func() {
			for {
				select {
				case <-ctx.Done():
					return // returning not to leak the goroutine
				case dst <- n:
					n++
				}
			}
		}()
		return dst
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel() // cancel when we are finished consuming integers

	for n := range gen(ctx) {
		fmt.Println(n)
		if n == 5 {
			break
		}
	}
	// Output:
	// 1
	// 2
	// 3
	// 4
	// 5
}
```

那么这个中，我们创建了一个gen的 func， 他接收一个ctx context.Context， 同时返回一个  <-chan int (一个只读的int channel)

那么在这个gen func里，

1. 首先make了一个buffer=0的 int channel dst（buffer=0的 channel意味着，当一个goroutine往该dst**写**入数据时，他会一直等待，直到有任何goroutine从dst中**读**数据。那么相反，如果是一个buffer>0 的channel 当一个goroutine往里写数据时，只要buffer没有被填满，该goroutine都无需等待。 make sence, right？）

2. n := 1

3. go func() {} 意味着开启了一个子goroutine，执行一个匿名的func, 而这个匿名func里是一个for循环，for循环里是一个select操作。那么incase你不知道什么是select：https://golang.google.cn/ref/spec#Select_statements  

   select statement用起来就像switch case一样，只是他的case都是channel操作（读或写channel），也就是说case后面跟的读或写操作可以被执行的话，该case语句就会被执行（假如多个case都能执行，select会选择任一个）

   那么继续看这个select statement, 有两个case,第一个是读ctx.Done()， ctx.Done()是Context接口的一个方法，返回的是一个channel，而这个channel往往会被Context手动或自动关闭，比如说如果是WithCancel的话，cancel方法被执行时，该channel就会被关闭。**而当一个channel被关闭时，这个channel总是可以被读**，那么这时对应的case就会被执行。

   同时，另一个case, 会向我们在step1里创建的buffer = 0 的 dst channel写入n, 并且case结构执行n++

4. 返回dst



回到example func，我们创建了一个WithCancel的ctx，并defer该ctx的cancel func, 意味着，在当前func（也就是 ExampleWithCancel），执行完成时，会调用cancel方法。

一旦cancel方法被调用，我们的ctx.Done()返回的channel就会被close, 而我们刚才已经提到，当一个channel被关闭时，这个channel总是可以被读，于是gen内部的goroutine将会执行对应的case语句，也就是return, 退出for循环。因此这个方法（ExampleWithCancel）不会涉及goroutine泄漏的风险。



继续，for循环，range gen(ctx), 

首先 gen(ctx) 会返回一个channel, 也就是dst。而range, 是一个golang的statement,类似于 iterater，他可以接受array, slice, channel, int, string and map, 不同的类型behavior会不同，参考：https://golang.google.cn/ref/spec#For_statements



> For channels, the iteration values produced are the successive values sent on the channel until the channel is [closed](https://golang.google.cn/ref/spec#Close). If the channel is `nil`, the range expression blocks forever.



也就是说，当我们for range一个channl, 他会一直读这个channel, 每次读，作为一次循环，**直到被closed**，而range返回的是被sent进channel的**value**



程序执行到这一行时，我们的gen方法已经执行完毕，返回了一个channel dst，同时内部开启了一个goroutine, 这个goroutine一直pend在select statement, 因为没有任何一个case可以被执行

1. ctx.Done()没有办法读，因为cancel函数还未被执行
2. dst没有办法被写，因为dst的buffer=0, 他必须等待另一个goroutine向dst读数据时，才能被写

而此时range statement试图读dst，使得内部goroutine对应的case2被执行，向dst写入n, 并执行n++，而外部的for循环因此读出dst里的n,开始一次循环



fmt.Println(n)， 打印循环体n，

判断n的数值



继续下一次循环，下一次循环意味着，range又再试图读取dst, 使得内部goroutine对应的case2被执行，向dst写入n, 并执行n++

直到n==5时，外部for循环break

而这一时刻，内部的goroutine还在继续，同样是因为：

1. ctx.Done()没有办法读，因为cancel函数还未被执行
2. dst没有办法被写，因为dst的buffer=0, 他必须等待另一个goroutine向dst读数据时，才能被写



此时ExampleWithCancel函数结束了，那么他会在结束前调用cancel函数，使得ctx.Done()返回的channel被关闭。**而当一个channel被关闭时，这个channel总是可以被读**（读出来的是对应的空值，比如说如果是int的话，就是0）。

因此，内部goroutine的的select case1就可以被执行，内部goroutine因此被return, 不会导致goroutine泄漏。



而这个example很好的展示了WithCancel的用法和cancel方法behavior, 怎么利用一个ctx来保护goroutine, 使他不要leak，而且可以看到，example_test.go的一个简单example, 其实包含了非常多前提知识，这对初学者来说并不容易。
