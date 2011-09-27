class aptsources {
	include apt

	package { [curl, debian-archive-keyring]: ensure => installed }

	exec { "add cert": 
		path => "/usr/bin/:/bin",
		command => "curl http://www.dotdeb.org/dotdeb.gpg | sudo apt-key add -",
		require => Package["curl", "debian-archive-keyring"],
		unless => "apt-key list | grep 3D624A3B",
	}

	repo { "dotdeb" :
		url => "http://packages.dotdeb.org",
		require => Exec["add cert"],
	}

	repo { "php53" :
		url => "http://php53.dotdeb.org",
		require => Exec["add cert"],
	}
}

define pearchannel() {
	exec { "pear channel-discover ${name}" :
		path => "/bin:/usr/bin",
		unless => "pear list-channels | grep '${name}'",
	}
}

class phpfpm {
	include aptsources

    package { ["php5-cli", "php5-common", "php5-suhosin", "php5-mysql", "php5-curl"]:
        ensure => installed,
        provider => apt,
        require => [Class["aptsources"], Exec["apt-update"]],
        notify => Service["php5-fpm"]
    }
    
    package { ["php5-fpm", "php5-cgi", "php-pear", "php5-gd"]:
        ensure => installed,
        provider => apt,
        require => Package["php5-cli"], # Order matters; install php5-cli first
        notify => Service["php5-fpm"]
    }
    
    service { "php5-fpm":
    	enable => true,
	    ensure => running,
	    require => Package["php5-fpm"],
	    hasrestart => true
    }

    exec { "phpunit install" :
    	path => "/usr/bin",
    	command => "pear install -a phpunit/PHPUnit",
    	require => [Exec["pear upgrade"], Pearchannel["pear.phpunit.de", "components.ez.no", "pear.symfony-project.com"]],
    	unless => "which phpunit",
    }

	pearchannel { ["pear.phpunit.de", "components.ez.no", "pear.symfony-project.com"]:
		require => Exec["pear upgrade"],
	}

    exec { "pear upgrade" :
    	command => "pear upgrade PEAR && pear upgrade && pear channel-update pear.php.net && pear upgrade-all",
    	path => "/usr/bin:/bin",
    	refreshonly => true,
    	require => Package["php-pear"] 
    }
}
