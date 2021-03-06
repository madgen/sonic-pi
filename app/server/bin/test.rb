#!/usr/bin/env ruby
#--
# This file is part of Sonic Pi: http://sonic-pi.net
# Full project source: https://github.com/samaaron/sonic-pi
# License: https://github.com/samaaron/sonic-pi/blob/master/LICENSE.md
#
# Copyright 2013, 2014, 2015 by Sam Aaron (http://sam.aaron.name).
# All rights reserved.
#
# Permission is granted for use, copying, modification, and
# distribution of modified versions of this work as long as this
# notice is included.
#++

require_relative "../core.rb"
require_relative "../sonicpi/lib/sonicpi/studio"
require_relative "../sonicpi/lib/sonicpi/spider"
require_relative "../sonicpi/lib/sonicpi/spiderapi"
require_relative "../sonicpi/lib/sonicpi/server"
require_relative "../sonicpi/lib/sonicpi/util"
require_relative "../sonicpi/lib/sonicpi/rcv_dispatch"

#Thread.abort_on_exception=true

include SonicPi::Util

ws_out = Queue.new
$scsynth = SonicPi::SCSynth.instance

$c = OSC::Client.new("localhost", 4556)

at_exit do
  $c.send(OSC::Message.new("/quit"))
end


$c.send(OSC::Message.new("/d_loadDir", synthdef_path))
sleep 2

user_methods = Module.new
name = "SonicPiSpiderUser1" # this should be autogenerated
klass = Object.const_set name, Class.new(SonicPi::Spider)
klass.send(:include, user_methods)
klass.send(:include, SonicPi::SpiderAPI)
$sp =  klass.new "localhost", 4556, ws_out, 5, user_methods
$rd = SonicPi::RcvDispatch.new($sp, ws_out)

$clients = []

# Send stuff out from Sonic Pi jobs out to GUI
out_t = Thread.new do
  continue = true
  while continue
    begin
      message = ws_out.pop
      message[:ts] = Time.now.strftime("%H:%M:%S")

      if message[:type] == :exit
        continue = false
      else
        puts message
      end
    rescue Exception => e
      puts "Exception!"
      puts e.message
      puts e.backtrace.inspect
    end
  end
end

Thread.new do
  f = File.open("/tmp/gc.txt", 'w')
  loop do
    f.puts GC.stat
    f.flush
    sleep 2
  end
end

def test_simple
  $rd.dispatch({:cmd => "run-code",
                :val => "play 60"})
end

def test_multi_osc
  $rd.dispatch({:cmd => "run-code",
                :val => "loop do ; status ; sleep 0.025 ; end"})
end

def test_multi_play
  $rd.dispatch({:cmd => "run-code",
                :val => "loop do ; play 60 ; sleep 0.025 ; end"})
end

def test_multi_threads
  $rd.dispatch({:cmd => "run-code",
                :val => "loop do ; in_thread do ; play 60 ; sleep 3 ; end ; sleep 0.025 ; end"})
end

def test_multi_similarly_named_threads
  $rd.dispatch({:cmd => "run-code",
                :val => "loop do ; in_thread(name: :foo) do ; play 60 ; sleep 3 ; end ; sleep 0.025 ; end"})
end

def test_multi_differently_named_threads
  $rd.dispatch({:cmd => "run-code",
                :val => "loop do ; in_thread(name: rand) do ; play 60 ; sleep 3 ; end ; sleep 0.025 ; end"})
end

def test_multi_inner_threads
  $rd.dispatch({:cmd => "run-code",
                :val => "loop do ; in_thread do ; in_thread do ; play 60 ; end ; end ; sleep 0.025 ; end"})
end

def test_multi_jobs
  loop do
    $rd.dispatch({:cmd => "run-code",
                  :val => "play 60"})
    sleep 0.025
  end
end

def test_multi_with_fx
  $rd.dispatch({:cmd => "run-code",
                :val => "loop do ; with_fx :slicer do ; play 60 ; sleep 0.025 ; end ; end"})
end

def test_stopping_within_fx_block
  loop do
    $rd.dispatch({:cmd => "run-code",
                  :val => "with_fx do ; loop do ; play 60 ; sleep 5 ; end ; end"})
    sleep 1
    $rd.dispatch({:cmd => "stop-jobs"})
    sleep 1
  end
end

def test_exception_throwing
  loop do
    $rd.dispatch({:cmd => "run-code",
                  :val => "play 60 ; 1/0"})
    sleep 0.025
  end
end

def test_exception_throwing_within_subthread
  loop do
    $rd.dispatch({:cmd => "run-code",
                  :val => "play 60 ; in_thread do ; 1/0 ; end"})
    sleep 0.025
  end
end

def test_all_jobs_stopping
  loop do
    $rd.dispatch({:cmd => "run-code",
                   :val => "loop do ; play 60 ; sleep 0.025 ; end"})
    sleep 3
    $rd.dispatch({:cmd => "stop-jobs"})
    sleep 1
  end
end

#test_simple
#test_multi_osc
#test_multi_play
#test_multi_threads
#test_multi_similarly_named_threads
#test_multi_differently_named_threads
#test_multi_inner_threads
#test_multi_jobs
test_multi_with_fx
#test_exception_throwing
#test_exception_throwing_within_subthread
#test_all_jobs_stopping



out_t.join
