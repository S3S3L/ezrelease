#!/usr/bin/expect
set timeout -1

set red "\033\[1;31m"
set green "\033\[2;32m"
set yellow "\033\[1;33m"
set blue "\033\[1;34m"
set non_color "\033\[;0m"

proc require_input { _msg } {

    set red "\033\[1;31m"
    set green "\033\[2;32m"
    set yellow "\033\[1;33m"
    set blue "\033\[1;34m"
    set non_color "\033\[;0m"
    
    send_user "${yellow}$_msg${non_color}"
	expect_user -re "(.*)\n"
	
	return "$expect_out(1,string)"
}

proc require_input_or_default { _msg _default } {

    set red "\033\[1;31m"
    set green "\033\[2;32m"
    set yellow "\033\[1;33m"
    set blue "\033\[1;34m"
    set non_color "\033\[;0m"
    
    send_user "${yellow}$_msg: ($_default) :${non_color}"
	expect_user -re "(.*)\n"
	
	set _input "$expect_out(1,string)"
	if { [string trim $_input] eq "" } {
	    return $_default
	} else {
	    return $_input
	}
}

proc choose { _msg } {
    set red "\033\[1;31m"
    set green "\033\[2;32m"
    set yellow "\033\[1;33m"
    set blue "\033\[1;34m"
    set non_color "\033\[;0m"
    
    while {true} {
        send_user "${yellow}$_msg?(yes/no) ${non_color}"
	    expect_user -re "(.*)\n"
	    set _choose "$expect_out(1,string)"
        switch $_choose {
            "yes" {
                return true
            }
            "no" {
                return false
            }
        }
    }
}

proc version_update { _new_version } {
    exec mvn versions:set -DnewVersion=$_new_version >@ stdout
}

proc is_all_change_commited {} {
    if {[exec git status --porcelain] eq "" } {
        return true
    } else {
        return false
    }
}

proc mvn_deploy { } {
    exec mvn clean deploy >@ stdout
}

proc git_commit { _msg } {
    exec git add .
    exec git commit -m $_msg >@ stdout
}

proc git_commit_submodule { _msg } {
    exec git submodule foreach git add .
    exec git submodule foreach git commit -m $_msg >@ stdout
}

proc git_tag { _tag _msg } {
    exec git tag -a $_tag -m $_msg
}

proc git_tag_submodule { _tag _msg } {
    exec git submodule foreach git tag -a $_tag -m $_msg >@ stdout
}

proc git_push_tag { _remote _tag } {
    exec git push $_remote $_tag >@ stdout
}

proc git_push_tag_submodule { _remote _tag } {
    exec git submodule foreach git push $_remote $_tag >@ stdout
}

proc git_push { _remote _branch } {
    set code [catch { exec git push $_remote $_branch >@ stdout } ""]
    switch -regexp $code {
        [01] {
            return true
        }
        default {
            exit 1
        }
    }
}

proc git_push_submodule { _remote _branch } {
    set code [catch { exec git submodule foreach git push $_remote $_branch >@ stdout }]
    switch -regexp $code {
        [01] {
            return true
        }
        default {
            exit 1
        }
    }
}

proc git_change_branch { _branch } {
    exec git checkout $_branch >@ stdout
}

proc git_change_branch_submodule { _branch } {
    exec git submodule foreach git checkout $_branch >@ stdout
}

if { ![is_all_change_commited] } {
    send_user "${red}Can not release when there are some changes not commited.\n${non_color}"
    exit 0
}

###########################################################################
# release

set home [pwd]
set pom_location [require_input "Parent pom location: "]
set release_version [require_input "Release version: "]
set is_submodule [choose "Is project a git submodule project"]
set git_remote [require_input_or_default "Git remote: " "origin"]
set git_branch [require_input_or_default "Git branch: " "master"]
set git_remote_branch [require_input_or_default "Git remote branch: " $git_branch]

set git_current_branch [exec git rev-parse --abbrev-ref HEAD]
set release_msg "\[release $release_version by ezrelease\]"
set release_tag "v$release_version"

if { $git_current_branch ne $git_branch } {
    if { $is_submodule } {
        git_change_branch_submodule $git_branch
    }

    git_change_branch $git_branch
}

# update version
cd $pom_location
version_update $release_version

cd $home

# commit & tag
set release_tag "v$release_version"
if { $is_submodule } {
    git_commit_submodule $release_msg
    git_tag_submodule $release_tag $release_msg
}

git_commit $release_msg
git_tag $release_tag $release_msg

# push commit & tag
set is_push [choose "Push commit"]
if { $is_push } {
    if { $is_submodule} {
        git_push_submodule $git_remote "$git_branch:$git_remote_branch"
        git_push_tag_submodule $git_remote $release_tag
    }
    
    git_push $git_remote "$git_branch:$git_remote_branch"
    git_push_tag $git_remote $release_tag
}

##################################################################
# new dev version

set new_develop_version [require_input "New develop version: "]
set develop_branch [require_input_or_default "Develop branch: " "dev"]
set remote_develop_branch [require_input_or_default "Remote develop branch: " $develop_branch]

set git_current_branch [exec git rev-parse --abbrev-ref HEAD]
set develop_msg "\[new develop version $new_develop_version by ezrelease\]"

# switch to dev branch
if { $git_current_branch ne $git_branch } {
    if { $is_submodule } {
        git_change_branch_submodule $git_branch
    }

    git_change_branch $git_branch
}

# update to new dev version
cd $pom_location
version_update $new_develop_version

cd $home

# commit
if { $is_submodule } {
    git_commit_submodule $develop_msg
}

git_commit $develop_msg

# push commit
if { $is_push } {
    if { $is_submodule} {
        git_push_submodule $git_remote "$git_branch:$remote_develop_branch"
    }
    
    git_push $git_remote "$git_branch:$remote_develop_branch"
}
