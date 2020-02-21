; program to play blackjack on the MU0

key_row1 EQU &FEF
key_row4 EQU &FF2
traffic_lights EQU &FFF
display_enable EQU &FFB
switches EQu &FEE
buzzer EQU &FFD
bargraph EQU &FFE

digit0 EQU &FF5
digit1 EQU &FF6
digit4 EQU &FF9
digit5 EQU &FFA

ORG 0 ; reset
JMP main

display_enable_signal DEFW &33

player_won_lights DEFW &009
player_lost_lights DEFW &024
seed_select_lights DEFW &FF
waiting_for_input_lights DEFW &12 

bargraph_on DEFW &FFFF

player_score_digit_tens DEFW 0
player_score_digit_ones DEFW 0

computer_score_digit_tens DEFW 0 
computer_score_digit_ones DEFW 0

lose_sound DEFW &8637
win_sound1 DEFW &8235
win_sound2 DEFW &8238
win_sound3 DEFW &8239
win_sound4 DEFW &823B

; constants for random number generation 
; random(n+1) = (a*random(n) + b) mod m
random DEFW 6 ; current random number, default value is the seed
weight DEFW 17
bias DEFW 0
m DEFW 2027
num_cards_suite DEFW 13 ; number of cards in deck

random_acc DEFW 0
random_mult_counter DEFW 0

current_player DEFW 0
A_pressed_keyboard DEFW &80
B_pressed_keyboard DEFW &40
reset_pressed_keyboard DEFW &80
card DEFW 0

player_digit_tens_divide_temp DEFW 0
computer_digit_tens_divide_temp DEFW 0
card_value_temp DEFW 0
delay_temp DEFW 0

player_initial_draw_count DEFW 2
computer_initial_draw_count DEFW 1

player_soft_aces DEFW 0
computer_soft_aces DEFW 0

; scores
player_score DEFW 0
computer_score DEFW 0

delay1 DEFW &7FFF
delay2 DEFW 5

zero DEFW 0
one DEFW 1
two DEFW 2
three DEFW 3
four DEFW 4
five DEFW 5
six DEFW 6
seven DEFW 7
eight DEFW 8
nine DEFW 9
ten DEFW 10
twentyone DEFW 21

negative_offset DEFW &8000

main

    ; reset variables
    LDA zero
    STA random
    STA player_score
    STA computer_score
    STA player_soft_aces
    STA computer_soft_aces
    LDA one
    STA computer_initial_draw_count
    LDA two
    STA player_initial_draw_count

    ; output zero scores
    LDA display_enable_signal
    STA display_enable
    LDA zero
    STA digit0
    STA digit1
    STA digit4
    STA digit5
    STA traffic_lights

    ; select random seed
    LDA seed_select_lights
    STA traffic_lights
    seed_select_loop LDA random
    ADD one
    STA random
    JGE check_reset_pressed ; reset random if it becomes negative
    LDA zero
    STA random
    check_reset_pressed LDA key_row4
    SUB reset_pressed_keyboard
    JNE seed_select_loop

game_loop

; give player two cards, computer one card at the beginning
LDA computer_initial_draw_count
JNE computer_initial_draw
LDA player_initial_draw_count
JNE player_initial_draw

LDA current_player
JNE pick_card

; get user choice
LDA waiting_for_input_lights ; turn on waiting lights
STA traffic_lights
user_wait_loop LDA key_row1
SUB B_pressed_keyboard
JNE check_A_pressed
JMP player_ended_turn ; B was pressed
check_A_pressed LDA key_row1
SUB A_pressed_keyboard
JNE user_wait_loop
LDA zero
STA traffic_lights ; turn lights off

; pick a random card
pick_card 

; wait a while
LDA delay2
STA delay_temp
delayloop1 LDA delay1
delayloop2 SUB one
JGE delayloop2
LDA delay_temp
SUB one
STA delay_temp
JGE delayloop1

; generate random number from seed
LDA weight
STA random_mult_counter

random_mult_loop
    LDA random_acc
    ADD random
    STA random_acc
    JGE update_random_mult_counter ; cycle the accumulator if it becomes negative
    SUB negative_offset
    STA random_acc
    update_random_mult_counter LDA random_mult_counter
    SUB one
    STA random_mult_counter
    JNE random_mult_loop

LDA random_acc
ADD bias

JGE random_mod ; make sure the accumulator does not overflow
SUB negative_offset

random_mod STA random_acc

; mod m
random_mod_loop
    SUB m
    JGE random_mod_loop

ADD m
STA random

LDA zero ; zero out the accumulator
STA random_acc

LDA random

; get card value 1 - 13
random_card_loop
    SUB num_cards_suite
    JGE random_card_loop

ADD num_cards_suite
JNE assign_value_non_ace
ADD one
STA card_value_temp
LDA current_player
JNE computer_drew_ace

LDA player_soft_aces ; player drew an ace
ADD one
STA player_soft_aces
LDA card_value_temp
JMP get_card_value ; the card is an ace, set value to 11 (soft)

computer_drew_ace LDA computer_soft_aces ; computer drew an ace
ADD one
STA computer_soft_aces
LDA player_soft_aces
JMP get_card_value ; the card is an ace, set value to 11 (soft)

assign_value_non_ace SUB nine ; assign a value of 10 to jack, queen and king (11, 12, 13)
JGE zero_acc
get_card_value ADD ten

STA card
LDA current_player
JNE add_to_computer_score

LDA card
ADD player_score
STA player_score
; update score on display

; display player's score on the left scoreboard
display_player_score LDA player_score

; output the ones digit
player_digit_ones_mod_loop
    SUB ten
    JGE player_digit_ones_mod_loop

ADD ten
STA player_score_digit_ones
STA digit4

; output the tens digit
print_player_tens LDA zero
STA player_score_digit_tens ; reset the tens digit
LDA player_score
SUB player_score_digit_ones
STA player_digit_tens_divide_temp

; divide by 10
player_digit_tens_divide_loop LDA player_digit_tens_divide_temp
    SUB ten
    STA player_digit_tens_divide_temp
    LDA player_score_digit_tens
    ADD one
    STA player_score_digit_tens
    LDA player_digit_tens_divide_temp
    JGE player_digit_tens_divide_loop

LDA player_score_digit_tens
SUB one ; we subtracted one extra time
STA player_score_digit_tens
STA digit5
JMP who_won

add_to_computer_score LDA card
ADD computer_score
STA computer_score
; update score on display

; display computer's score on right scoreboard
display_computer_score LDA computer_score

; output the ones digit
computer_digit_ones_mod_loop
    SUB ten
    JGE computer_digit_ones_mod_loop
tens
ADD ten
STA computer_score_digit_ones
STA digit0

; output the tens digit
print_computer_tens LDA zero
STA computer_score_digit_tens ; reset the tens digit
LDA computer_score
SUB computer_score_digit_ones
STA computer_digit_tens_divide_temp

; divide by 10
computer_digit_tens_divide_loop LDA computer_digit_tens_divide_temp
    SUB ten
    STA computer_digit_tens_divide_temp
    LDA computer_score_digit_tens
    ADD one
    STA computer_score_digit_tens
    LDA computer_digit_tens_divide_temp
    JGE computer_digit_tens_divide_loop

LDA computer_score_digit_tens
SUB one ; we subtracted one extra time
STA computer_score_digit_tens
STA digit1

LDA player_initial_draw_count ; player still has to draw a initial card
JNE game_loop

who_won
LDA current_player
JNE check_computer_won

; check if player lost or got a blackjack
LDA player_score
SUB twentyone
JGE player_check_bust
JMP game_loop ; if it was neither, continue to next turn

player_check_bust
JNE player_try_harden
JMP player_ended_turn ; player got a blackjack, but we have to be sure that computer does not get one

player_try_harden LDA player_soft_aces
JNE player_harden_ace
JMP player_lost
player_harden_ace SUB one
STA player_soft_aces
LDA player_score
SUB ten
STA player_score

LDA bargraph_on
STA bargraph

; delay before changing score
LDA delay2
STA delay_temp
player_harden_delayloop1 LDA delay1
player_harden_delayloop2 SUB one
JGE player_harden_delayloop2
LDA delay_temp
SUB one
STA delay_temp
JGE player_harden_delayloop1

LDA zero ; turn bargraph off
STA bargraph

JMP display_player_score

player_won LDA player_won_lights ; player got a blackjack
STA traffic_lights
LDA win_sound1
STA buzzer
LDA win_sound2
STA buzzer
LDA win_sound3
STA buzzer
LDA win_sound4
STA buzzer
JMP ask_restart

check_computer_won
LDA computer_score
SUB twentyone
JGE computer_check_bust

; if computer is winning, end turn, else play on
LDA computer_score
SUB player_score
JGE player_lost
JMP game_loop

computer_check_bust
JNE computer_try_harden
JMP player_lost ; computer got a blakjack

computer_try_harden LDA computer_soft_aces
JNE computer_harden_ace
JMP player_won
computer_harden_ace SUB one
STA computer_soft_aces
LDA computer_score
SUB ten
STA computer_score

LDA bargraph_on
STA bargraph

; delay before changing score
LDA delay2
STA delay_temp
computer_harden_delayloop1 LDA delay1
computer_harden_delayloop2 SUB one
JGE computer_harden_delayloop2
LDA delay_temp
SUB one
STA delay_temp
JGE computer_harden_delayloop1

LDA zero ; turn bargraph off
STA bargraph

JMP display_computer_score

player_ended_turn ; player ended their turn, now it's computer's turn to play
LDA one
STA current_player
JMP game_loop


player_lost
; player lost the game
LDA lose_sound
STA buzzer
LDA player_lost_lights
STA traffic_lights
JMP ask_restart

; set accumalator to zero while calculating card value
zero_acc
LDA zero
JMP get_card_value

player_initial_draw LDA player_initial_draw_count
SUB one
STA player_initial_draw_count
LDA zero ; set current_player to player
STA current_player
JMP pick_card

computer_initial_draw LDA computer_initial_draw_count
SUB one
STA computer_initial_draw_count
LDA one ; set current_player to computer
STA current_player
JMP pick_card

ask_restart LDA switches ; if the player presses thw switch, restart the game
    SUB one
    JNE check_quit
    JMP main
    check_quit SUB one
    JNE ask_restart
    STP
    