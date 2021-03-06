require 'formula'

class Nginx < Formula
  homepage 'http://nginx.org/'
  url 'http://nginx.org/download/nginx-1.4.5.tar.gz'
  sha1 '96c1aecd314f73a3c30a0db8c39ad15ddacb074e'

  devel do
    url 'http://nginx.org/download/nginx-1.5.10.tar.gz'
    sha1 '89e2317c0d27a7386f62c3ba9362ae10b05e3159'
  end

  head 'http://hg.nginx.org/nginx/', :using => :hg

  bottle do
    sha1 "b5964496b5365e51cc9b7eb838b0499795e71861" => :mavericks
    sha1 "2757fecb0611a6dd6e22a8122f775b917fac476f" => :mountain_lion
    sha1 "f64a845d905589c9ad580ab4d5e6fe27c0eb53f9" => :lion
  end

  env :userpaths

  option 'with-passenger', 'Compile with support for Phusion Passenger module'
  option 'with-webdav', 'Compile with support for WebDAV module'
  option 'with-debug', 'Compile with support for debug log'
  option 'with-spdy', 'Compile with support for SPDY module'
  option 'with-gunzip', 'Compile with support for gunzip module'

  depends_on 'pcre'
  depends_on 'passenger' => :optional
  depends_on 'openssl'

  def passenger_config_args
    passenger_config = "#{HOMEBREW_PREFIX}/opt/passenger/bin/passenger-config"
    nginx_ext = `#{passenger_config} --nginx-addon-dir`.chomp

    if File.directory?(nginx_ext)
      return "--add-module=#{nginx_ext}"
    end

    puts "Unable to install nginx with passenger support."
    exit
  end

  def install
    # Changes default port to 8080
    inreplace 'conf/nginx.conf', 'listen       80;', 'listen       8080;'

    pcre = Formula["pcre"]
    openssl = Formula["openssl"]
    cc_opt = "-I#{pcre.include} -I#{openssl.include}"
    ld_opt = "-L#{pcre.lib} -L#{openssl.lib}"

    args = ["--prefix=#{prefix}",
            "--with-http_ssl_module",
            "--with-pcre",
            "--with-ipv6",
            "--sbin-path=#{bin}/nginx",
            "--with-cc-opt=#{cc_opt}",
            "--with-ld-opt=#{ld_opt}",
            "--conf-path=#{etc}/nginx/nginx.conf",
            "--pid-path=#{var}/run/nginx.pid",
            "--lock-path=#{var}/run/nginx.lock",
            "--http-client-body-temp-path=#{var}/run/nginx/client_body_temp",
            "--http-proxy-temp-path=#{var}/run/nginx/proxy_temp",
            "--http-fastcgi-temp-path=#{var}/run/nginx/fastcgi_temp",
            "--http-uwsgi-temp-path=#{var}/run/nginx/uwsgi_temp",
            "--http-scgi-temp-path=#{var}/run/nginx/scgi_temp",
            "--http-log-path=#{var}/log/nginx/access.log",
            "--error-log-path=#{var}/log/nginx/error.log",
            "--with-http_gzip_static_module"
          ]

    args << passenger_config_args if build.include? 'with-passenger'
    args << "--with-http_dav_module" if build.include? 'with-webdav'
    args << "--with-debug" if build.include? 'with-debug'
    args << "--with-http_spdy_module" if build.include? 'with-spdy'
    args << "--with-http_gunzip_module" if build.include? 'with-gunzip'

    if build.head?
      system "./auto/configure", *args
    else
      system "./configure", *args
    end
    system "make"
    system "make install"
    man8.install "objs/nginx.8"
    (var/'run/nginx').mkpath

    # nginx's docroot is #{prefix}/html, this isn't useful, so we symlink it
    # to #{HOMEBREW_PREFIX}/var/www. The reason we symlink instead of patching
    # is so the user can redirect it easily to something else if they choose.
    prefix.cd do
      dst = HOMEBREW_PREFIX/"var/www"
      if not dst.exist?
        dst.dirname.mkpath
        mv "html", dst
      else
        rm_rf "html"
        dst.mkpath
      end
      Pathname.new("#{prefix}/html").make_relative_symlink(dst)
    end

    # for most of this formula's life the binary has been placed in sbin
    # and Homebrew used to suggest the user copy the plist for nginx to their
    # ~/Library/LaunchAgents directory. So we need to have a symlink there
    # for such cases
    if (HOMEBREW_CELLAR/'nginx').subdirs.any?{|d| (d/:sbin).directory? }
      sbin.mkpath
      sbin.cd do
        (sbin/'nginx').make_relative_symlink(bin/'nginx')
      end
    end
  end

  test do
    system "#{bin}/nginx", '-t'
  end

  def passenger_caveats; <<-EOS.undent

    To activate Phusion Passenger, add this to #{etc}/nginx/nginx.conf:
      passenger_root #{HOMEBREW_PREFIX}/opt/passenger/libexec/lib/phusion_passenger/locations.ini
      passenger_ruby /usr/bin/ruby
    EOS
  end

  def caveats
    s = <<-EOS.undent
    Docroot is: #{HOMEBREW_PREFIX}/var/www

    The default port has been set in #{HOMEBREW_PREFIX}/etc/nginx/nginx.conf to 8080 so that
    nginx can run without sudo.
    EOS
    s << passenger_caveats if build.with? 'passenger'
    s
  end

  plist_options :manual => 'nginx'

  def plist; <<-EOS.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <false/>
        <key>ProgramArguments</key>
        <array>
            <string>#{opt_prefix}/bin/nginx</string>
            <string>-g</string>
            <string>daemon off;</string>
        </array>
        <key>WorkingDirectory</key>
        <string>#{HOMEBREW_PREFIX}</string>
      </dict>
    </plist>
    EOS
  end
end
