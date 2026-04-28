# Carnival of Consructs

These are samples of the kinds of constructs the ANSI renderer for `fatty` are capable of.


## Unordered Lists

-   builtin commands are handled by the `fatty` demo, Four score and seven years ago our fathers brought forth on this continent, a new nation, conceived in Liberty, and dedicated to the proposition that all men are created equal.
-   other commands are handled by `/bin/sh`
-   keybindings are listed below


## Ordered Lists

1.  builtin commands are handled by the `fatty` demo, Four score and seven years ago our fathers brought forth on this continent, a new nation, conceived in Liberty, and dedicated to the proposition that all men are created equal.
2.  other commands are handled by `/bin/sh`
3.  keybindings are listed below


## Description Lists

-   **bold:** **this text is bold**
-   **italic:** *this text is italic*
-   **code:** `this text is code`
-   **verbatim:** `this text is verbatim`
-   **strike:** ~~this text is strike-through~~
-   **underline:** <span class="underline">this text is underlined</span>

```ruby
    def wrap(text, first_prefix: "", rest_prefix: first_prefix)
      width = [@width.to_i, 20].max

      words = text.to_s.split(/\s+/)
      lines = []
      line = +""

      words.each do |word|
        prefix = lines.empty? ? first_prefix : rest_prefix
        available = width - Fatty::Ansi.visible_length(prefix)
        available = 20 if available < 20

        candidate = line.empty? ? word : "#{line} #{word}"

        if Fatty::Ansi.visible_length(candidate) > available && !line.empty?
          lines << "#{prefix}#{line}"
          line = word.dup
        else
          line = candidate
        end
      end

      unless line.empty?
        prefix = lines.empty? ? first_prefix : rest_prefix
        lines << "#{prefix}#{line}"
      end

      lines.join("\n")
    end
```


## Nested lists

-   Parent item
    -   Child item
    -   Another child
-   Back to parent


## Links

[Fatty on GitHub](<https://github.com/ddoherty03/fatty>)


## Block quotes

> Four score and seven years ago our fathers brought forth on this continent, a new nation, conceived in Liberty, and dedicated to the proposition that all men are created equal.
> 
> Now we are engaged in a great civil war, testing whether that nation, or any nation so conceived and so dedicated, can long endure. We are met on a great battle-field of that war. We have come to dedicate a portion of that field, as a final resting place for those who here gave their lives that that nation might live. It is altogether fitting and proper that we should do this.
> 
> But, in a larger sense, we can not dedicate&#x2014;we can not consecrate&#x2014;we can not hallow&#x2014;this ground. The brave men, living and dead, who struggled here, have consecrated it, far above our poor power to add or detract. The world will little note, nor long remember what we say here, but it can never forget what they did here. It is for us the living, rather, to be dedicated here to the unfinished work which they who fought here have thus far so nobly advanced. It is rather for us to be here dedicated to the great task remaining before us&#x2014;that from these honored dead we take increased devotion to that cause for which they gave the last full measure of devotion&#x2014;that we here highly resolve that these dead shall not have died in vain&#x2014;that this nation, under God, shall have a new birth of freedom&#x2014;and that government of the people, by the people, for the people, shall not perish from the earth.


## Tables with styled cells

| Feature | Example         |
|------- |--------------- |
| bold    | **bold cell**   |
| code    | \`code cell\`   |
| strike  | ~~strike cell~~ |


## Fenced code with various languages

Here is the Fibonacci number computed recursively in various languages.


### Ruby

```ruby
def fib(n)
  return n if n < 2

  fib(n - 1) + fib(n - 2)
end
puts fib(10)
```


### Python

```python
def fib(n):
    if n < 2:
        return n

    return fib(n - 1) + fib(n - 2)

print(fib(10))

```


### C

```c
#include <stdio.h>

int fib(int n)
{
  if (n < 2) {
    return n;
  }

  return fib(n - 1) + fib(n - 2);
}

int main(void)
{
  printf("%d\n", fib(10));
  return 0;
}
```


### C++

```cpp
#include <iostream>

int fib(int n)
{
  if (n < 2) {
    return n;
  }

  return fib(n - 1) + fib(n - 2);
}

int main()
{
  std::cout << fib(10) << std::endl;
}
```


### Go

```go
package main

import "fmt"

func fib(n int) int {
	if n < 2 {
		return n
	}

	return fib(n-1) + fib(n-2)
}

func main() {
	fmt.Println(fib(10))
}
```


### Rust

```rust
fn fib(n: u32) -> u32 {
    if n < 2 {
        n
    } else {
        fib(n - 1) + fib(n - 2)
    }
}

fn main() {
    println!("{}", fib(10));
}
```


### PHP

```php
<?php

function fib($n)
{
    if ($n < 2) {
        return $n;
    }

    return fib($n - 1) + fib($n - 2);
}

echo fib(10) . PHP_EOL;
```


### ### JavaScript

```javascript
function fib(n) {
  if (n < 2) {
    return n;
  }

  return fib(n - 1) + fib(n - 2);
}

console.log(fib(10));
```


### TypeScript

```typescript
function fib(n: number): number {
  if (n < 2) {
    return n;
  }

  return fib(n - 1) + fib(n - 2);
}

console.log(fib(10));
```


### Java

```java
public class Fib {
  static int fib(int n) {
    if (n < 2) {
      return n;
    }

    return fib(n - 1) + fib(n - 2);
  }

  public static void main(String[] args) {
    System.out.println(fib(10));
  }
}
```


### Shell

```bash
fib() {
  if [ "$1" -lt 2 ]; then
    echo "$1"
  else
    a=$(fib $(($1 - 1)))
    b=$(fib $(($1 - 2)))
    echo $((a + b))
  fi
}

fib 10
```


### Haskell

```haskell
fib :: Int -> Int
fib n
  | n < 2     = n
  | otherwise = fib (n - 1) + fib (n - 2)

main :: IO ()
main = print (fib 10)
```


### SQL (Recursive CTE)

```sql
WITH RECURSIVE fib(n, a, b) AS (
  SELECT 0, 0, 1
  UNION ALL
  SELECT n + 1, b, a + b
  FROM fib
  WHERE n < 10
)
SELECT a
FROM fib
ORDER BY n DESC
LIMIT 1;
```
