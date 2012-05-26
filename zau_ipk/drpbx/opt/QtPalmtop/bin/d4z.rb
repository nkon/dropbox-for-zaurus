#!/usr/bin/env ruby

require 'dropbox_sdk'
require 'pp'
require 'time'        # Date._parse
require 'fileutils'   # mkdir_p
require 'optparse'

# APP_KEY, APP_SECRET, ACCESS_TOKEN, ACCESS_SECRET
keys_path = File.expand_path("~/d4z_keys.rb")
unless File.exist?(keys_path)
  keys_path = File.expand_path("./d4z_keys.rb")
end
unless File.exist?(keys_path)
  puts "'d4z_keys.rb' does not exists. Aborted."
  exit
end

require keys_path


ACCESS_TYPE = :app_folder

STRFTIME_RFC2616 = "%a, %d %b %Y %H:%M:%S %z"    # httpdate

Version = "0.0.1"   # dropbox client for zaursu version

class DropboxCLI
  LOGIN_REQUIRED = %w{put get getsp cp mv rm ls lsr mkdir info logout search thumbnail load_info save_info get_info get_local listup do_sync delta}

  def initialize
    if APP_KEY == '' or APP_SECRET == ''
      puts "You must set your APP_KEY and APP_SECRET in cli_example.rb!"
      puts "Find this in your apps page at https://www.dropbox.com/developers/"
      exit
    end
    @session = DropboxSession.new(APP_KEY, APP_SECRET)
    @client = nil

    @info_local = Hash.new
    @info_server = Hash.new
    @info_cache = Hash.new
    @info_delta = Hash.new
    @put_file = Array.new
    @get_file = Array.new
    @makedir = Array.new
    @md_local = Array.new

  end

  def login
    if ACCESS_TOKEN == '' or ACCESS_SECRET == ''
      @session.get_request_token
      authorize_url = @session.get_authorize_url
      puts "Got a request token.  Your request token key is #{@session.request_token.key} and your token secret is #{@session.request_token.secret}"
      puts "AUTHORIZING", authorize_url, "Please visit that web page and hit 'Allow', then hit Enter here."
      puts "Set ACCESS_TOKEN and ACCESS_SECRET in cli_example.rb!"
      exit
    end

    @session.set_access_token(ACCESS_TOKEN, ACCESS_SECRET)
    if @session.authorized?
      puts "You are logged in.  Your access token key is #{@session.access_token.key} your secret is #{@session.access_token.secret}"
    end
    @client = DropboxClient.new(@session, ACCESS_TYPE)
  end

  def command_loop
    puts "Enter a command or 'help' or 'exit'"
    command_line = ''
    while command_line.strip != 'exit'
      begin
        execute_dropbox_command(command_line)
      rescue RuntimeError => e
        puts "Command Line Error! #{e.class}: #{e}"
        puts e.backtrace
      end
      print '>'
      command_line = gets.strip
    end
    puts 'goodbye'
    exit(0)
  end

  def execute_dropbox_command(cmd_line)
    command = cmd_line.split
    method = command.first
    if LOGIN_REQUIRED.include? method
      if @client
        send(method.to_sym, command)
      else
        puts 'must be logged in; type \'login\' to get started.'
      end
    elsif ['login', 'help'].include? method
      send(method.to_sym)
    else
      if command.first && !command.first.strip.empty?
        puts 'invaild command. type \'help\' to see commands.'
      end
    end
  end

  def logout(command)
    @session.clear_access_token
    puts "You are logged out."
    @client = nil
  end

  # put local_name (remote_name)
  def put(command)
    fname = command[1]

    if command[2]
      new_name = command[2]
    else
      new_name = File.basename(fname)
    end

    ## check fname is valid file
    if fname && !fname.empty? && File.exist?(fname) && (File.ftype(fname) == 'file') && File.stat(fname).readable?
      #This is where we call the the Dropbox Client
      pp @client.put_file(new_name, open(fname))
    else
      puts "couldn't find the file #{ fname }"
    end
  end

  # get remote_name local_name
  def get(command)
    dest = command[2]
    if !command[1] || command[1].empty?
      puts "please specify item to get"
    elsif !dest || dest.empty?
      puts "please specify full local path to dest, i.e. the file to write to"
    elsif File.exist?(dest)
      puts "error: File #{dest} already exist."
    else
      src = clean_up(command[1])
      out, metadata = @client.get_file_and_metadata('/' + src)
      puts "Metadata:"
      pp metadata
      open(dest, 'w'){|f| f.puts out}
      puts "wrote file #{dest}."
    end
  end

  def getsp(command)
    resp = @client.metadata('/')
    for item in resp['contents']
      if item['is_dir']
      else
        fname = clean_up(item['path'])
        out = @client.get_file(item['path'])
        open(fname, 'w'){|f| f.puts out}
      end
    end
  end


  # mkdir remote_dir
  def mkdir(command)
    pp @client.file_create_folder(command[1])
  end

  # Example:
  # > thumbnail pic1.jpg ~/pic1-local.jpg large
  def thumbnail(command)
    dest = command[2]
    command[3] ||= 'small'
    out,metadata = @client.thumbnail_and_metadata(command[1], command[3])
    puts "Metadata:"
    pp metadata
    open(dest, 'w'){|f| f.puts out }
    puts "wrote thumbnail#{dest}."
  end

  def cp(command)
    src = clean_up(command[1])
    dest = clean_up(command[2])
    pp @client.file_copy(src, dest)
  end

  def mv(command)
    src = clean_up(command[1])
    dest = clean_up(command[2])
    pp @client.file_move(src, dest)
  end

  def rm(command)
    pp @client.file_delete(clean_up(command[1]))
  end

  def search(command)
    resp = @client.search('/',clean_up(command[1]))

    for item in resp
      puts item['path']
    end
  end

  def info(command)
    pp @client.account_info
  end

  def ls(command)
    command[1] = '/' + clean_up(command[1] || '')
    resp = @client.metadata(command[1])

    if resp['contents'].length > 0
      for item in resp['contents']
        puts item['path']
      end
    end
  end

  def lsr(command)
    command[1] = '/' + clean_up(command[1] || '')
    resp = @client.metadata(command[1])

    pp resp

    if resp['contents'].length > 0
      for item in resp['contents']
        if item['is_dir']
          puts item['path']+'/'
          lsr ["lsr", "#{item['path']}/"]
        else
          puts item['path']
        end
      end
    end
  end

  def help
    puts "commands are: login #{LOGIN_REQUIRED.join(' ')} help exit"
  end

  # load cached server information to @info_cache
  def load_info(command)
    path = command[1] || SERVER_INFO_FILE
    @info_cache = JSON.parse(File.read(path))
    @cursor = @info_cache["cursor"]
  rescue => e
    puts "Caught error @load_info: #{e.class}:#{e}"

    # make data of default root directory
    @info_cache = {"/" => {"path" => "/", "hash" => "", "contents" => [] }}
    pp @info_cache if $debug_flag
  else
    puts "#{SERVER_INFO_FILE} is loaded." if $debug_flag
  end

  def save_info(command)
    @info_cache.merge! @info_delta
    @info_cache.merge! @info_server
    path = command[1] || SERVER_INFO_FILE
    File.open(path, 'w'){|f|
      f.puts JSON.generate(@info_cache)
    }
    puts "#{SERVER_INFO_FILE} is saved."
  end

  # get full information from server
  # @info_server is cleared and set information
  def get_info(command)
    path = command[1] || "/"
    @info_server = Hash.new
    get_info_directory(path)

    t = Time.now
    @info_cache["last_info"] = t.to_i
    @info_cache["last_info_t"] = t.to_s

    pp @info_server if $debug_flag
  end

  def get_info_directory(path)
    resp = @client.metadata(path)
    puts "get_info_directory(#{path})"
    pp resp

    @info_server[path.downcase] = {
      'path'       => resp['path'],
      'is_dir'     => resp['is_dir'],
      'rev'        => resp['rev'],
      'modified'   => resp['modified'],
      'modified_t' => resp['modified'] ? Time.parse(resp['modified']).to_i : nil,
      'hash'       => resp['hash'],
    }

    if resp['contents'].length > 0
      for item in resp['contents']
        if item['is_dir'] == true
          get_info_directory(item['path'] + "/")
        else
          path = item['path']

          @info_server[path.downcase] = {
            'path'       => item['path'],
            'bytes'      => item['bytes'],
            'is_dir'     => item['is_dir'],
            'rev'        => item['rev'],
            'modified'   => item['modified'],
            'modified_t' => Time.parse(item['modified']).to_i,
          }
        end
      end  # for item in resp['contents']
    end   # if resp['contents'].length > 0
  end

  # get local information to @info_local
  def get_local(command)
    path = command[1] || path_remote_to_local("/")
    @info_local = Hash.new
    get_local_directory(path)
    pp @info_local if $debug_flag
  end

  def get_local_directory(path)
    puts "get_local_directory(#{path})" if $debug_flag

    app_path = path_local_to_remote(path)

    @info_local[app_path.downcase] = {
      'path'       => app_path,
      'is_dir'     => true,
      'modified'   => File.stat(path).mtime.strftime(STRFTIME_RFC2616),
      'modified_t' => File.stat(path).mtime.to_i
    }

    Dir.foreach(path){|file|
      next if file == "."
      next if file == ".."
      next if file == ".dropbox"
      path_file = path + file
      if (File.stat(path_file).directory?)
        get_local_directory(path_file + "/")
      else
        app_path = path_local_to_remote(path_file)
        @info_local[app_path.downcase] ={
          'path'       => app_path,
          'bytes'      => File.stat(path_file).size,
          'is_dir'     => false,
          'modified'   => File.stat(path_file).mtime.strftime(STRFTIME_RFC2616),
          'modified_t' => File.stat(path_file).mtime.to_i,
        }
      end
    }
  end

  def delta(command)
    arg_cursor = clean_up(command[1])
    @cursor = nil unless(@cursor)
    @cursor = arg_cursor if (arg_cursor)

    puts "delta: cursor => #{@cursor}"
    while
      resp = @client.delta(@cursor)
      pp resp

      @cursor = resp["cursor"]

      if resp["reset"]
        puts "delta require RESET cached information."
        @info_cache = Hash.new
      end

      resp["entries"].each{|item|
        next unless item[1]
        path = item[0]
        metadata = item[1]
        path = append_slash(path) if item[1]['is_dir']
        metadata['path'] = append_slash(metadata['path']) if item[1]['is_dir']
        @info_delta[path.downcase] = {
          'path'       => metadata['path'],
          'is_dir'     => metadata['is_dir'],
          'rev'        => metadata['rev'],
          'modified'   => metadata['modified'],
          'modified_t' => metadata['modified'] ? Time.parse(metadata['modified']).to_i : nil,
          'hash'       => metadata['hash'],
        }
      }

      break unless resp["has_more"]

    end

    @info_cache["cursor"] = @cursor

    t = Time.now
    @info_cache["last_delta"] = t.to_i
    @info_cache["last_delta_t"] = t.to_s

    pp @info_delta if $debug_flag
  end

  def listup(command)
    files = (@info_local.keys + @info_server.keys + @info_cache.keys + @info_delta.keys).sort.uniq
    pp files if $debug_flag

    @put_file = Array.new
    @get_file = Array.new
    @makedir = Array.new
    @md_local = Array.new

    @info_merge = @info_cache.merge @info_delta
    @info_merge.merge! @info_server

    files.each{|f|
      next if f == "/"
      next if f =~ /[^\ -\~]/  # not ASCII
      next if f =~ /\\/        # not "\"
      next unless f =~ /^\//       # not ^/  => meta information

      puts "check #{f}" if $debug_flag
      if f =~ /\/$/            # directory
        if @info_local[f] and !@info_merge[f]        # local dir is new
          debug_listup(f,"local dir is new")
          @makedir.push @info_local[f]['path']
        elsif !@info_local[f] and @info_merge[f]     # server dir is new
          debug_listup(f,"server dir is new")
          @md_local.push @info_merge[f]['path']
        end

      else                     # file
        if @info_local[f] and !@info_merge[f]        # local file is new
          debug_listup(f,"local file is new")
          @put_file.push @info_local[f]['path']
        elsif !@info_local[f] and @info_merge[f]     # server file is new
          debug_listup(f,"server file is new")
          @get_file.push @info_merge[f]['path']
        elsif @info_local[f] and @info_merge[f]
          if @info_local[f]['modified_t'] == @info_merge[f]['modified_t']
            next

          # local is newer
          elsif @info_local[f]['modified_t'] > @info_merge[f]['modified_t']
            debug_listup(f,"local is newer")
            @put_file.push @info_local[f]['path']

          # server is newer
          elsif @info_local[f]['modified_t'] < @info_merge[f]['modified_t']
            debug_listup(f,"server is newer")
            @get_file.push @info_merge[f]['path']
          end
        end
      end
    }

    if $debug_flag
      puts "@put_file"
      pp @put_file
      puts "@get_file"
      pp @get_file
      puts "@makedir"
      pp @makedir
      puts "@md_local"
      pp @md_local
    end
  end

  def debug_listup(f,str)
    return unless $debug_flag
    puts str
    pp "local", @info_local[f] if @info_local[f]
    pp "merge", @info_merge[f] if @info_merge[f]
    pp "server", @info_server[f] if @info_server[f]
    pp "cache", @info_cache[f] if @info_cache[f]
    pp "delta", @info_delta[f] if @info_delta[f]
  end

  def do_sync(command)
    command = {
      "md_local" => true,
      "get_file" => true,
      "makedir"  => true,
      "put_file" => true,
    } if command.is_a? Array
    pp command if $debug_flag

    @md_local.each{|f|
      puts "do_sync: @md_local(#{f})"
      dst = path_remote_to_local(f)
      puts "FileUtils.mkdir_p(#{dst})"
      FileUtils.mkdir_p(dst)
    } if (command["md_local"])

    @get_file.each{|f|
      puts "do_sync: @get_file(#{f})"
      src = clean_up(f)
      begin
        out, metadata = @client.get_file_and_metadata('/' + src)
      rescue DropboxError => e
        pp e
      else
        puts "Metadata:"
        pp metadata if $debug_flag
        dst = path_remote_to_local(src)
        open(dst, 'w'){|f| f.puts out}

        puts "get #{src} #{dst}"
        t = Time.parse(metadata['modified'])
        File::utime(t,t,dst)
      end
    } if (command["get_file"])

    @makedir.each{|f|
      puts "do_sync: @makedir(#{f})"
      dst = clean_up(f)
      puts "@client.file_create_folder(#{dst})"
      pp @client.file_create_folder(dst)
    } if (command["mkdir"])

    @put_file.each{|f|
      puts "do_sync: @put_file(#{f})"
      src = path_remote_to_local(f)
      dst = clean_up(f)
      puts "@client.put_file(#{dst}, open(#{src}), true)"
      pp @client.put_file(dst, open(src), true)  ## overrite=true
    } if (command["put_file"])

    t = Time.now
    @info_cache["last_sync"] = t.to_i
    @info_cache["last_sync_t"] = t.to_s
  end

  # remove the head-slash
  def clean_up(str)
    return str.gsub(/^\/+/, '') if str
    str
  end

  # append "/" at last if not existed
  def append_slash(str)
    return str.gsub(/\/+$/,'') + "/"
  end

  # remove APP_DIRECTORY from head
  def path_local_to_remote(str)
    return str.gsub(/^#{APP_DIRECTORY}/,'')
  end

  def path_remote_to_local(str)
    return APP_DIRECTORY + "/" + clean_up(str)
  end

end

cli = DropboxCLI.new
opt = OptionParser.new

OPT = Hash.new
$debug_flag = false

#opt.on('-h') {|v| p v}
opt.on('-i', 'Interructive mode') {|v|
  p 'Interructive mode'
  p "Show verbose debug output(automaticaly set)"
  $debug_flag = true
  OPT['i'] = true
}
opt.on('-d', 'Download only(from server to local)') {|v|
  p 'Download only(from server to local)'
  OPT['d'] = true
}

opt.on('-u', 'Upload only(from local to server)') {|v|
  p 'Upload only(from local to server)'
  OPT['u'] = true
}
opt.on('-s', 'Syncronus(upload and download)') {|v|
  p 'Syncronus(upload and download)'
  OPT['s'] = true
}

opt.on_tail("--debug", "Show verbose debug output") do
  p "Show verbose debug output"
  $debug_flag = true
end

opt.on_tail("-h", "--help", "Show this message") do
  puts opt.help
  exit
end

opt.on_tail("-v", "--version","Show version") do
  puts opt.ver
  exit
end

begin
  opt.parse!(ARGV)
rescue OptionParser::ParseError
  puts opt.help
  exit
end

### main
if (OPT['i'])
  cli.login
  cli.load_info []
  cli.command_loop
  cli.save_info []
  exit
elsif (OPT['d'])
  cli.login
  cli.load_info []
  cli.get_local []
  cli.delta []
  cli.listup []
  cli.do_sync({"md_local" => true, "get_file" => true})
  cli.save_info []
  exit
elsif (OPT['u'])
  cli.login
  cli.load_info []
  cli.get_local []
  cli.delta []
  cli.listup []
  cli.do_sync({"makedir" => true, "put_file" => true})
  cli.save_info []
  exit
elsif (OPT['s'])
  cli.login
  cli.load_info []
  cli.get_local []
  cli.delta []
  cli.listup []
  cli.do_sync({"md_local" => true, "makedir" => true, "get_file" => true, "put_file" => true})
  cli.save_info []
  exit
else
  puts opt.help
end
