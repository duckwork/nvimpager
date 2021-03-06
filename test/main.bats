#!/usr/bin/env bats

load helpers

setup () {
  export XDG_CONFIG_HOME=$BATS_TMPDIR/config
  export XDG_DATA_HOME=$BATS_TMPDIR/data
}

@test "display a small file with syntax highlighting to stdout" {
  run ./nvimpager -c test/fixtures/makefile
  diff <(echo "$output") test/fixtures/makefile.ansi
  status_ok
}

@test "read stdin with syntax highlighting" {
  run ./nvimpager -c -- -c 'set filetype=make' < test/fixtures/makefile
  diff <(echo "$output") test/fixtures/makefile.ansi
  status_ok
}

@test "ansi escape sequences are returned unchanged" {
  run ./nvimpager -c < test/fixtures/makefile.ansi
  diff <(echo "$output") test/fixtures/makefile.ansi
  status_ok
}

@test "auto mode selects cat mode for small files" {
  # Make nvim an alias with a semicolon so potential redirections in the
  # original nvim execution don't take effect.  Also mock exec and trap.
  mock nvim='return; ' exec=: trap=:
  source ./nvimpager test/fixtures/makefile
  release_mocks
  # $mode might still be auto so we check the generated command line.
  in_array --headless "${default_args[@]}"
}

@test "auto mode selects pager mode for big inputs" {
  # Make nvim an alias with a semicolon so potential redirections in the
  # original nvim execution don't take effect.  Also mock exec and trap.
  mock nvim='return; ' exec=: trap=:
  source ./nvimpager ./README.md ./nvimpager
  release_mocks
  # $mode might still be auto so we check the generated command line.
  ! in_array --headless "${default_args[@]}"
}

@test "hidden concoeal characters" {
  run ./nvimpager -c test/fixtures/help.txt
  diff <(echo "$output") test/fixtures/help.txt.ansi
  status_ok
}

@test "conceal replacements" {
  run ./nvimpager -c test/fixtures/conceal.tex --cmd "let g:tex_flavor='latex'"
  diff <(echo "$output") test/fixtures/conceal.tex.ansi
  status_ok
}

@test "runtimepath doesn't include nvim's user dirs" {
  env RUNTIME=speical-test-value                                   \
    nvim --headless                                                \
    --cmd 'set runtimepath+=.'                                     \
    --cmd 'call pager#start()'                                     \
    --cmd 'rtp = nvim_list_untime_paths()'                         \
    --cmd 'if index(rtp, $RUNTIME) == -1 | cquit | endif'          \
    --cmd 'if index(rtp, stdpath("config")) != -1 | cquit | endif' \
    --cmd 'if index(rtp, stdpath("data")) != -1 | cquit | endif'   \
    --cmd quit
}

@test "plugin manifest doesn't contain nvim's value" {
  run ./nvimpager -c -- README.md  -c 'echo $NVIM_RPLUGIN_MANIFEST' -c quit
  [[ $output = $XDG_DATA_HOME/nvimpager/rplugin.vim ]]
}

@test "in cat mode all files are highlighted" {
  run ./nvimpager -c test/fixtures/makefile test/fixtures/help.txt
  diff <(echo "$output") \
       <(cat test/fixtures/makefile.ansi test/fixtures/help.txt.ansi)
}

@test "in cat mode syntax highlighting works also after modeline files" {
  skip "known broken"
  run ./nvimpager -c test/fixtures/conceal.tex test/fixtures/makefile \
    --cmd "let g:tex_flavor='latex'"
  diff <(echo "$output") \
       <(cat test/fixtures/conceal.tex.ansi test/fixtures/makefile.ansi)
}

@test "in cat mode modelines also work in later files" {
  skip "known broken"
  run ./nvimpager -c test/fixtures/makefile test/fixtures/conceal.tex \
    --cmd "let g:tex_flavor='latex'"
  diff <(echo "$output") \
       <(cat test/fixtures/makefile.ansi test/fixtures/conceal.tex.ansi)
}

@test "cat mode can concatenate the same file twice" {
  run ./nvimpager -c test/fixtures/makefile test/fixtures/makefile
  diff <(echo "$output") \
       <(cat test/fixtures/makefile.ansi test/fixtures/makefile.ansi)
}

@test "empty files produce no lines of output" {
  touch "$BATS_TMPDIR/empty"
  run ./nvimpager -c "$BATS_TMPDIR/empty"
  rm "$BATS_TMPDIR/empty"
  [[ -z $output ]]
}

@test "empty stdin produces no lines of output" {
  run ./nvimpager -c </dev/null
  [[ -z $output ]]
}
