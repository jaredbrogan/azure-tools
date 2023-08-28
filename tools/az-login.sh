#!/usr/bin/env bash
##############################################################################################
#                                                                                            #
#        db      MMM"""AMV         `7MMF'        .g8""8q.     .g8"""bgd `7MMF'`7MN.   `7MF'  #
#       ;MM:     M'   AMV            MM        .dP'    `YM. .dP'     `M   MM    MMN.    M    #
#      ,V^MM.    '   AMV             MM        dM'      `MM dM'       `   MM    M YMb   M    #
#     ,M  `MM       AMV              MM        MM        MM MM            MM    M  `MN. M    #
#     AbmmmqMA     AMV   ,           MM      , MM.      ,MP MM.    `7MMF' MM    M   `MM.M    #
#    A'     VML   AMV   ,M           MM     ,M `Mb.    ,dP' `Mb.     MM   MM    M     YMM    #
#  .AMA.   .AMMA.AMVmmmmMM         .JMMmmmmMMM   `"bmmd"'     `"bmmmdPY .JMML..JML.    YM    #
#                                                                                            #
################################ Created by: Jared Brogan ####################################                                                                                        

# Usage Examples:
#   Interactive     = ./az_login.sh
#   Non-interactive = ./az_login.sh "subscription name"

# Global variables
subscription="${1}"
Bash_Version=$(echo "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}")
if [[ $(echo "$Bash_Version >= 4.2" | bc -l) -eq 1 ]]; then
  bullet_point=$(echo -e '\u2022')
else
  bullet_point="-"
fi

WSL2=$(uname -r | grep -q WSL2$ ; echo $?)
if [[ "$WSL2" -eq 0 ]]; then
  export BROWSER=/usr/bin/wslview
fi

# Functions
function select_option {
  # Renders a text based list of options that can be selected by the
  # user using up, down and enter keys and returns the chosen option.
  #
  #   Arguments   : list of options, maximum of 256
  #                 "opt1" "opt2" ...
  #   Return value: selected index (0 for opt1, 1 for opt2 ...)

    # little helpers for terminal print control and key input
    ESC=$( printf "\033")
    cursor_blink_on()  { printf "$ESC[?25h"; }
    cursor_blink_off() { printf "$ESC[?25l"; }
    cursor_to()        { printf "$ESC[$1;${2:-1}H"; }
    print_option()     { printf "   $1 "; }
    print_selected()   { printf "  $ESC[7m $1 $ESC[27m"; }
    get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
    key_input()        { read -s -n3 key 2>/dev/null >&2
                         if [[ $key = $ESC[A ]]; then echo up;    fi
                         if [[ $key = $ESC[B ]]; then echo down;  fi
                         if [[ $key = ""     ]]; then echo enter; fi; }

    # initially print empty new lines (scroll down if at bottom of screen)
    for opt; do printf "\n"; done

    # determine current screen position for overwriting the options
    local lastrow=`get_cursor_row`
    local startrow=$(($lastrow - $#))

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local selected=0
    while true; do
        # print options by overwriting the last lines
        local idx=0
        for opt; do
            cursor_to $(($startrow + $idx))
            if [ $idx -eq $selected ]; then
                print_selected "$opt"
            else
                print_option "$opt"
            fi
            ((idx++))
        done

        # user key control
        case `key_input` in
            enter) break;;
            up)    ((selected--));
                   if [ $selected -lt 0 ]; then selected=$(($# - 1)); fi;;
            down)  ((selected++));
                   if [ $selected -ge $# ]; then selected=0; fi;;
        esac
    done

    # cursor position back to normal
    cursor_to $lastrow
    printf "\n"
    cursor_blink_on

    return $selected
}

preflight_check(){
  if [[ "$(az version >/dev/null 2>&1 ; echo $?)" -ne 0 ]]; then
    echo "[ERROR] Azure CLI appears to not be installed. Please install and try again."
    echo "  ${bullet_point} https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux"
    echo -e "  ${bullet_point} Exiting...\n"
    exit 3
  elif [[ "$(jq --version >/dev/null 2>&1 ; echo $?)" -ne 0 ]]; then
    echo "[ERROR] The package 'jq' appears to not be installed. Please install and try again."
    echo "  ${bullet_point} https://stedolan.github.io/jq/download/"
    echo -e "  ${bullet_point} Exiting...\n"
    exit 4
  fi
}

az_login(){
  # Variables
  subscription="${1}"

  timeout 1m az login -o none >/dev/null 2>&1
  valid_login="$?"

  if [[ "${valid_login}" -eq 0 ]]; then
    wait ; sleep 2 ; echo
    if [[ -z "${subscription}" ]]; then
      mapfile -t subscription_list < <(az account list | jq .[].name | grep -v "N/A")
      echo -e "Please select a subscription from below [\U2191\U2193]:"
      select_option "${subscription_list[@]}"
      choice="$?"
      echo -e "You selected: ${subscription_list[$choice]}\n"
      sub="${subscription_list[$choice]}"
      subscription="${sub:1:${#sub}-2}"
      az account set -s "${subscription}"
      az account show
    else
      az account set -s "${subscription}" >/dev/null 2>&1
      valid_sub="$?"
      if [[ "${valid_sub}" -ne 0 ]]; then
        echo "[ERROR] Invalid subscription detected. Please review your subscription access and try again."
        echo -e "  ${bullet_point} Exiting...\n"
        exit 5
      else
        az account show
      fi
    fi
  else
    echo "[ERROR] Unsuccessful login attempt. Please review your credentials and try again."
    echo -e "  ${bullet_point} Exiting...\n"
    exit 6
  fi
}


#__main__
preflight_check
az_login "${subscription}"
