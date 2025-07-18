require "net/http"
require "json"
require "json/add/core"
require "open-uri"
require "uri"

namespace :github do
  desc "Github上からコントリビューションのデータをインポート"
  task import_contributions: :environment do
    user = User.first
    query = <<~GRAPHQL
      query {
        user(login: "kei2kei") {
          contributionsCollection {
            contributionCalendar {
              weeks {
                contributionDays {
                  date,
                  color,
                  contributionCount
                }
              }
            }
          }
        }
      }
    GRAPHQL

    token = ENV["GITHUB_TOKEN"]
    endpoint_url = "https://api.github.com/graphql"

    uri = URI.parse(endpoint_url)
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true

    request_header = {
      "Authorization": "bearer #{token}",
      "Content-Type": "application/json"
    }
    begin
      request = Net::HTTP::Post.new(uri.request_uri, request_header)
      request.body = JSON.generate({ query: query })

      response = https.request(request)
      response_body = JSON.parse(response.body)

      # 先週のデータを抽出、nilエラーを防ぐためdigを使用
      data_of_last_week = response_body.dig("data", "user", "contributionsCollection", "contributionCalendar", "weeks", -1, "contributionDays")
      data_of_last_week&.each do | data_of_day |
        # 各データにはその日の日付、色（草の色）、コントリビューション数が入っている。
        date, color, contribution_count = data_of_day.values_at("date", "color", "contributionCount")

        # テーブルへの保存、重複回避のためにfind_or_initializeを使用し、レコードが新しいか確認
        contribution = user.git_hub_contributions.find_or_initialize_by(user_id: user.id, date: date)
        if contribution.new_record?
          contribution.color = color
          contribution.contribution_count = contribution_count
          contribution.save!
        # 新たなレコードじゃ無いかつ変更があれば更新
        elsif contribution.color != color || contribution.contribution_count != contribution_count
          contribution.update!(color: color, contribution_count: contribution_count)
        end
      end
      puts "インポート完了"
    rescue => e
      puts "GitHub APIエラー: #{e.message}"
      puts e.backtrace.join("\n")
    end
  end
end

