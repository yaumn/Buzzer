.section .text
.globl exit

exit:
	.type exit, @function
	movl %eax, %ebx
	movl $1, %eax
	int $0x80
