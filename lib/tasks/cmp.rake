require Rails.root.join('lib', 'query.rb').to_s
require Rails.root.join('lib', 'cmp.rb').to_s

namespace :cmp do
  namespace :orgs do
    desc 'saves spreadsheet of org matches'
    task save_org_matches: :environment do
      file_path = Rails.root
                    .join('data', "cmp_orgs_matched_#{Time.current.strftime('%F')}.csv").to_s

      blank_match_values = {
        match1_name: nil, match1_id: nil, match1_values: nil,
        match2_name: nil, match2_id: nil, match2_values: nil
      }

      sheet = Cmp::Datsets.orgs.map do |cmp_org|
        attrs = cmp_org.attributes.merge(blank_match_values)

        EntityMatcher
          .find_matches_for_org(cmp_org.fetch(:cmpname))
          .first(2) # take first 2 matches
          .each.with_index do |match, idx|

          attrs["match#{idx + 1}_name".to_sym] = match.entity.name
          attrs["match#{idx + 1}_id".to_sym] = match.entity.id
          attrs["match#{idx + 1}_values".to_sym] = match.values.to_a.join('|')
        end
        attrs[:pre_selected] = Cmp::EntityMatch.matches.dig(cmp_org.cmpid.to_s, 'entity_id')
        attrs
      end
      Query.save_hash_array_to_csv file_path, sheet
      puts "Saved orgs to: #{file_path}"
    end

    desc 'import orgs excel sheet'
    task import: :environment do
      ThinkingSphinx::Callbacks.suspend!
      Cmp.import_orgs
      ThinkingSphinx::Callbacks.resume!
    end
  end

  namespace :people do
    desc 'saves spreadsheet of people matches'
    task :save_people_matches, [:take] => :environment do |_, args|
      if args[:take].present?
        file_path_root = "cmp_people_matched_#{Time.current.strftime('%F')}_limited.csv"
        take = args[:take].to_i
        puts "saving the first #{take} rows"
      else
        file_path_root = "cmp_people_matched_#{Time.current.strftime('%F')}.csv"
        puts "saving the all rows"
        take = Cmp::Datasets.people.to_a.length
      end

      file_path = Rails.root.join('data', file_path_root)

      blank_match_values = {
        match1_name: nil, match1_id: nil, match1_values: nil,
        match2_name: nil, match2_id: nil, match2_values: nil
      }

      write_limit = 1000
      write_queue = []

      Cmp::Datasets.people.to_a.take(take).map(&:second).each do |cmp_person|
        begin
          attrs = cmp_person.attributes.merge(blank_match_values)

          cmp_person.matches.first(2).each.with_index do |match, idx|
            attrs["match#{idx + 1}_name".to_sym] = match.entity.name
            attrs["match#{idx + 1}_id".to_sym] = match.entity.id
            attrs["match#{idx + 1}_values".to_sym] = match.values.to_a.join('|')
          end
          write_queue << attrs
        rescue => e
          puts '--------------------------------------------------------'
          puts "Error encontered with cmp person: #{cmp_person.cmpid}"
          puts e
          puts '--------------------------------------------------------'
        end

        if write_queue.length >= write_limit
          Query.save_hash_array_to_csv file_path, write_queue, mode: 'ab'
          write_queue.clear
        end
      end

      Query.save_hash_array_to_csv file_path, write_queue, mode: 'ab' unless write_queue.empty?
      puts "Saved people to: #{file_path}"
    end
  end
end