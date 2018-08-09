# Many Users
Quick and dirty script for ubuntu to let other people work on your PC at the same time

## Usage
at least you have to set the variable `CHILD_USER` to a username which exists on your computer and then start `./find_input_and_start.sh`

e.g.
```
CHILD_USER=mirjam ./find_input_and_start.sh
```

## other variables
Other variables you might want to set when starting the script are:

* `RESOLUTION` to set the resolution of the "child" display
  e.g. `RESOLUTION=800x600`
* `DISP_NUM` a number higher than 2 if you want more than one additional user to use your computer
  e.g.
  ```
CHILD_USER=user1 DISP_NUM=2 ./find_input_and_start.sh
```
... then in an other terminal
  ```
CHILD_USER=next_user DISP_NUM=3 ./find_input_and_start.sh
```
