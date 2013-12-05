require 'csv'
require 'base64'
require 'openssl'
require 'digest'


module Encryption
  def encrypt(key, data)
    key = Digest::SHA256.digest(key) if(key.kind_of?(String) && 32 != key.bytesize)
    aes = OpenSSL::Cipher.new('AES-256-CBC')
    aes.encrypt
    aes.key = key
    aes.update(data) + aes.final
  end

  def decrypt(key, data)
    key = Digest::SHA256.digest(key) if(key.kind_of?(String) && 32 != key.bytesize)
    aes = OpenSSL::Cipher.new('AES-256-CBC')
    aes.decrypt
    aes.key = key
    aes.update(data) + aes.final
  end
end

module Validations
  def numerical?(number)
    number =~ /\d+/   
  end

  def wordical?(word)
    word =~ /[a-zA-Z\s]+/
  end

  def phone_number?(number)
    number =~ /^\(?([0-9]{3})\)?[-. ]?([0-9]{3})[-. ]?([0-9]{4})$/
  end
end

module SantaHelper
  
  def unique_person(group, person)
    !group.participants.any?{|x| x.name == person[0] && x.number == person[1]}
  end

end

class SecretSanta
  include Validations
  include SantaHelper
  include Encryption
  attr_reader :group
  
  def initialize
    @group = Group.new
    @done = false
    main_menu
  end

  def main_menu
    puts 'Welcome to Secret Santa'
    puts 'Please select an option:'
    puts choices
    choose_option(gets.chomp.to_i)
    main_menu if !@done
  end
  
  def choose_option(option)
    if (1..choices.length).include?(option)
      case option
      when 1 then get_participants
      when 2 then view_participants
      when 3 then match_make
      when 4 then save
      when 5 then load_group
      when 6 then quit
      end
    else
      puts 'Not a valid choice'
      choose_option(gets.chomp.to_i)
    end
  end

  def save
    @group.user ||= set_user
    @password ||= set_password
    CSV.open('secret_santa.csv', 'a+', encoding: 'iso-8859-1', headers: true) do |file|
      data = [@group.user, encrypt( @password, Marshal.dump(@group))]
      previous_data = file.find {|row| row['user'] == @group.user}
      if previous_data
        if decrypt(@password, previous_data['group'])
          previous_data = data
        end
      else
        write_data(@group, @password)
      end
    end
    puts "Successfully saved group"
  end

  def write_data(group, key)
    CSV.open('secret_santa.csv', 'a', headers: true) do |file|
      file.puts [group.user, encrypt(key, Marshal.dump(group))]
    end
  end

  def load_group
    puts 'Please enter your username'
    user = gets.chomp
    puts 'Please enter the password for your group'
    password = gets.chomp
    if login(user, password)
      puts 'Successfully loaded group'
    else
      puts 'Sorry. Couldn\'t find that group'
    end
  end

  def login(user, password)
    CSV.foreach('secret_santa.csv', encoding: 'iso-8859-1', headers: true) do |row|
      if row['user'] == user
        begin
          @group = Marshal.load(decrypt(password, row['group']))
          return true
        rescue
          return false
        end
      end
    end
    false
  end

  def set_user
    puts 'Please enter a username'
    @group.user = gets.chomp
  end

  def set_password
    puts 'Please enter a password for your group'
    @password = gets.chomp
  end

  def quit
    print 'Goodbye'
    @done = true
  end

  def choices
    ['1. Add participants',
     '2. View participants',
     '3. Match make',
     '4. Save',
     '5. Load',
     '6. Exit'
    ]
  end

  def match_make
    if group_exists
      participants = @group.participants.map{|x| x.name}
      @group.matches = Matchmaker.new(participants).match
    else
      puts 'You need some participants first'
    end
  end
  
  def group_exists
    @group && @group.participants.any?
  end

  def view_participants
    if group_exists
      @group.participants.each {|x| p x.name}
    else
      puts 'There are no participants currently'
    end
  end

  def get_participants
    if get_input_choice == 'txt'
      ParticipantReader.new(get_file_name, @group).import_participants
    else
      get_manual_participants
    end
  end

  def get_manual_participants
    while !more_participants ||= false
      manual_input
      puts "Would you like to enter another participant?"
      more_participants = get_choice(gets.chomp)
    end
  end

  def get_choice(input)
    input.downcase[0] =~ /[n]/
  end

  def manual_input
    puts "What is the name of the participant?"
    name = get_name(gets.chomp)
    puts "What is their phone number?"
    number = get_number(gets.chomp)
    @group.participants << Participant.new(name, number) if check_participant(name, number)
  end

  def check_participant(name, number)
    if unique_person(@group, [name, number])
      true
    else
      puts "You've already added this participant"
      manual_input
    end
  end

  def get_name(name)
    if wordical?(name)
      name
    else
      puts 'Not a valid name'
      get_name(gets.chomp)
    end
  end

  def get_number(number)
    if phone_number?(number)
      number
    else
      puts 'Not a valid number'
      get_number(gets.chomp)
    end
  end

  def get_file_name
    puts 'Please enter the file name'
    file = gets.chomp
    if valid_txt_file(file)
      file
    else
      puts 'Sorry that\'s not a valid txt file'
      get_file_name
    end
  end
  
  def valid_txt_file(file)
    File.exists?(file) && file =~ /(\.txt)\z/
  end

  def get_input_choice
    puts 'How would you like to upload names?'
    puts 'Enter txt for a text file or manual to do it manually'
    gets.chomp
  end
end

class Group
  attr_accessor :participants, :matches, :user
  def initialize
    @participants = []
    @matches = nil
    @user = nil
  end
end

class Participant
  attr_reader :name, :number

  def initialize(name, number=nil)
    @name = name
    @number = number
  end
end

class Matchmaker
  def initialize(participants)
    @participants = participants
    @matches = {}
  end

  def match
    begin
      receivers = @participants.dup
      @participants.each do |participant|
        receiver = receivers.reject{|x| x== participant}.sample
        @matches[participant] = receiver
        receivers.delete(receiver)
      end
      @matches
    rescue
      match
    end
  end

end

class ParticipantReader
  include SantaHelper

  def initialize(filename, group)
    @filename = filename
    @group = group
  end

  def import_participants
    File.open(@filename) do |file|
      file.each_line do |person|
        person = person.chomp.split(',')
        if unique_person(@group, person)
          @group.participants << Participant.new(person[0], person[1])
        end
      end
    end
  end
end


