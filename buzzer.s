.section .text
.globl _start
.extern printf
.include "exit.s"

	
### Constants
.equ READ_WRITE, 2
.equ RIGHTS, 0644	
	
.equ NO_BUZZER_ACTIONNED, 6	# random value > to the number of buzzers + 1 to know if one them has been actionned
.equ NO_BUTTON_ACTIONNED, 7	# random value > to the number of buttons + 1 to know if one them has been actionned

	
_start:
	.type _start, @function

	## Get file's descriptor
	leal file_path, %esi
	pushl $READ_WRITE
	pushl %esi
	call open
	addl $8, %esp
 
main_loop:
	xorl %ebx, %ebx
	
	## Read input
	pushl %eax
	call read
	addl $4, %esp
	## Analyse the input
	call analyze_buffer_in

	## If no buzzer has been actionned, go to the beginning of the loop
	cmpl $NO_BUZZER_ACTIONNED, %ebx
	je main_loop

	## Display a message
	## printf change the registers so they must be restored from the stack
	pushl %eax
	pushl %ebx
	pushl %ecx
	leal display_message, %esi
	pushl %esi
	call printf
	addl $4, %esp
	popl %ecx
	addl $4, %esp
	popl %eax

blink_buzzer:	
	## Switch on buzzer
	leal buffer_out, %esi
	## The pointer is moved to the correct byte which is changed to 0xFF (switched on)
	## The first two bytes are not used but the first buzzer value in %ebx is 1, so only 1 is added to %esi
	incl %esi
	addl %ebx, %esi
	movl $0xFF, (%esi)
	subl %ebx, %esi
	decl %esi
	pushl %esi
	pushl %eax
	call write
	addl $8, %esp

	call wait

	## Switch off the buzzer the same way it was switched on
	incl %esi
	addl %ebx, %esi
	movl $0, (%esi)
	subl %ebx, %esi
	decl %esi
	pushl %esi
	pushl %eax
	call write
	addl $8, %esp

	call wait

	loopnz blink_buzzer
	
	jmp main_loop		# Infinite loop that will stop when 2 buzzers are actionned


### Stops the program for a certain time
wait:	
	.type wait, @function
	pushl %ebp
	movl %esp, %ebp
	pushl %ecx

	movl $500000000, %ecx

next:
	loop next
	
	popl %ecx
	movl %ebp, %esp
	popl %ebp
	ret

	
### Analyze the input buffer so that at the end, %ebx is the buzzer number
### and %ecx is the button number
### If two buzzers are actionned, the program stops (as written in the subject)
analyze_buffer_in:
	.type analyze_buffer_in, @function
	pushl %ebp
	movl %esp, %ebp
	pushl %eax
	pushl %esi

	xorl %eax, %eax		# Contains buffer_in
	leal buffer_in, %esi
	movl 2(%esi), %eax 	# The first two bytes are not used

	andl $0xFFFFF, %eax 	# Set the third byte's second half and fourth byte to 0 as they aren't used as well

	xorl %ecx, %ecx 	# Current buzzer
	pushl $NO_BUZZER_ACTIONNED
	pushl $NO_BUTTON_ACTIONNED
	
check_buzzer:
	xorl %edx, %edx 	# Current button
	incl %ecx
	cmpl $5, %ecx
	je analysis_end

check_button:
	incl %edx
	cmpl $6, %edx
	je check_buzzer
	test $1, %eax
	jnz button_actionned

go_to_next_button:	
	shrl %eax
	jmp check_button
	
button_actionned:
	cmpl %ecx, 4(%esp)	
	jl exit_program		# If another buzzer has already been actionned
	movl %ecx, 4(%esp) 	# Keep in mind the buzzer actionned
 	movl %edx, (%esp)	# Keep in mind the button actionned
	jmp go_to_next_button
	
analysis_end:
	popl %ecx 		# Now contains the button number
	popl %ebx		# Now contains the buzzer number
	popl %esi
	popl %eax
	movl %ebp, %esp
	popl %ebp
	ret

exit_program:
	## Display an error message
	leal error_message, %esi
	pushl %esi
	call printf
	addl $4, %esp

	## Close file
	pushl %eax
	call close
	addl $4, %esp
	
	## Bye bye
	call exit

	
### Reads the file into buffer_in 
### Takes 1 parameter : the descriptor of the file
read:
	.type read, @function
	pushl %ebp
	movl %esp, %ebp
	pushl %eax
	pushl %ebx
	pushl %ecx
	pushl %edx

	movl 8(%ebp), %ebx 	# descriptor
	movl $3, %eax
	movl $8, %edx
	leal buffer_in, %ecx
	int $0x80
	
	popl %edx
	popl %ecx
	popl %ebx
	popl %eax
	movl %ebp, %esp
	popl %ebp
	ret
	
	
### Writes buffer_out into the file 
### Takes 1 parameter : the descriptor of the file
write:
	.type write, @function
	pushl %ebp
	movl %esp, %ebp
	pushl %eax
	pushl %ebx
	pushl %ecx
	pushl %edx
	
	movl 8(%ebp), %ebx
	movl $4, %eax
	movl $8, %edx
	movl 12(%ebp), %ecx
	int $0x80
	
	popl %edx
	popl %ecx
	popl %ebx
	popl %eax
	movl %ebp, %esp
	popl %ebp
	ret

	
### Opens the file corresponding to file_path
### Takes 2 parameters : the file path and the opening mode
### Returns the file descriptor
open:
	.type open, @function
	pushl %ebp
	movl %esp, %ebp
	pushl %ebx
	pushl %ecx
	pushl %edx
	
	movl $5, %eax
	movl 8(%ebp), %ebx 	# file path
	movl 12(%ebp), %ecx 	# opening mode
	movl $RIGHTS, %edx
	int $0x80
	
	popl %edx
	popl %ecx
	popl %ebx
	movl %ebp, %esp
	popl %ebp
	ret

	
### Closes the file corresponding to the given descriptor
### Takes 1 parameter : the file's descriptor
close:
	.type close, @function
	pushl %ebp
	movl %esp, %ebp
	pushl %eax
	pushl %ebx

	movl $6, %eax
	movl 8(%ebp), %ebx 	# file's descriptor
	int $0x80
	
	popl %ebx
	popl %eax
	movl %ebp, %esp
	popl %ebp
	ret

	
.section .data
file_path:
	.string "/dev/hidraw3"
	
error_message:
	.string "Deux buzzers ont ete actionnes, le programme s'arrete\n"

display_message:
	.string "Le bouton %d du buzzer %d a ete actionne\n"
	
.section .bss
	.lcomm buffer_in, 8
	.lcomm buffer_out, 8
