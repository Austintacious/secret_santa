require 'rspec'
require_relative '../santa.rb' 

describe 'encryption' do
  include Encryption
   
  let(:password) {'hello'}
  let(:data) {'This is some secret text'}
  let(:encrypted_data) {encrypt(password, data)}

  it 'should encrypt data' do
    expect(encrypt(password, data)).to_not eql(data)
  end

  it 'should decrypt data if the right password is given' do
    expect(decrypt(password, encrypted_data)).to eql(data)
  end

  it 'should raise an error if the wrong password is given' do
    lambda{(decrypt('wrong_password', encrypted_data))}.should raise_error(OpenSSL::Cipher::CipherError)
  end
end
