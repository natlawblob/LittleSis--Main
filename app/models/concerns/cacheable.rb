module Cacheable
	extend ActiveSupport::Concern

	included do 
	end

	def cache_key(subkey=nil, use_timestamp=false, params=nil)
	  if new_record?
	    key = "#{self.class.model_name.cache_key}/new#{subkey}"
	  else
	  	if use_timestamp && (timestamp = max_updated_column_timestamp)
	  		timestamp = timestamp.utc.to_s(cache_timestamp_format)
		  	id = "#{id}-#{timestamp}"
		  else
		  	id = self.id
		  end

			key = "#{self.class.model_name.cache_key}/#{id}/#{subkey}"
	  end

	  key += "/#{self.class.params_to_key(params)}" if params.present?
	  key
	end

	def delete_cache(subkey=nil, use_timestamp=false, params=nil)
		Rails.cache.delete(cache_key(subkey, use_timestamp, params))
	end

	def clear_cache(subkey=nil)
		if new_record?
			pattern = "*#{self.class.model_name.cache_key}/new[\\/\\-]*"
		else
			sub = subkey.present? ? subkey + "*" : nil
			pattern = "*#{self.class.model_name.cache_key}/#{self.id}[\\/\\-]*#{sub}"
		end
		p pattern
		Rails.cache.delete_matched(pattern)
	end

	module ClassMethods
		def cache_key_with_params(key, params)
			return key if params.blank?
			key + "/" + params_to_key(params)
		end

		def params_to_key(params)
			params = Hash[params.sort]
			params.to_a.flatten.join("/")
		end
	end
end