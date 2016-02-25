require 'spec_helper'

describe 'IdleManager' do
	context '#prestart' do
		before do
			@pool = ActiveRecord::Base.connection_pool
			@pool.disconnect!
			@pool.prestart(5)
		end

		it 'prestart generates correct number of connections' do
			size = @pool.connections.size
			expect(size).to eq 5
		end
	end
end
