alias ca=console_animation_clear_test

console_animation_clear_test() {
    for d in 0.1 0.01 0.001; do
        for ((p=3; p>=0; p--));do
          printf "\r  $d second delay per line, next in: $p"
          sleep 1 
        done

        for _ in $(seq 1 $LINES); do
            echo
            sleep $d
        done
    done
}

