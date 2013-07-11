module Ahora
	module Error

		# Base error class
		class Error < StandardError; end

		# Wrap the original exception
		class ClientError < Error
			attr_reader :wrapped_exception

			def initialize ex
				@wrapped_exception = nil

				if ex.respond_to? :message
					super ex.message
					@wrapped_exception = ex
				end
			end
		end

		# Distinct timeout errors
		class TimeoutError < ClientError; end
	end
end