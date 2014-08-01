
require "json"

include RethinkDB::Shortcuts

DBNAME = "phaultnews"
DBHOST = "localhost"
DBPORT = 28015

class UpdateFeedsJob
  include SuckerPunch::Job

  def perform repeat, target = nil
    puts "Refreshing feeds:", target
    con = r.connect :host => DBHOST, :port => DBPORT, :db => DBNAME
    (target || r.table("feeds").run(con)).each_slice(5) do |items|
      feeds = Hash[items.map {|i| [i["url"], i] }]
      posts = []
      
      for url, feed in Feedjira::Feed.fetch_and_parse feeds.keys
        if feeds[url]["etag"] != feed.etag
          r.table("feeds").get(feeds[url]["id"])
                          .update({etag: feed.etag}).run(con)

          for entry in feed.entries
            e = entry.force_to_h
            e["feed"] = feeds[url]["id"]
            posts << e
          end
        end
      end

      r.table("posts").insert(posts, :upsert => true).run(con)
    end
  rescue
    puts "#{Time.now} - Failed to refresh feeds"
  ensure
    con.close if con
    after(repeat) { perform repeat } if repeat
  end
end

configure do
  begin
    con = r.connect :host => DBHOST, :port => DBPORT
  rescue
    puts "Failed to connect to the database"
  end

  begin
    r.db_create(DBNAME).run(con)
    con.use(DBNAME)

    r.table_create("feeds").run(con)
    r.table_create("posts", :primary_key => "entry_id").run(con)
    
    r.table("posts").index_create("published").run(con)
    r.table("posts").index_create("feed").run(con)
  rescue
  end

  con.close
  UpdateFeedsJob.new.async.perform(1200)
end

before do
  begin
    @con = r.connect :host => DBHOST, :port => DBPORT, :db => DBNAME
  rescue
    puts "Failed to connect to the database"
  end
end

after do
  @con.close if @con
end

post "/feed" do
  content_type :json

  puts "TEST:", params["url"]

  unless params["url"]
    return {success: false, err: "No URL Provided"}.to_json
  end

  args = {
    url: params["url"],
    title: params["title"] || params["url"]
  }

  output = r.table("feeds").insert(args, :return_vals => true).run(@con)
  UpdateFeedsJob.new.async.perform nil, [output["new_val"]]

  {success: true, feed: output["new_val"]}.to_json
end

get "/feed" do
  content_type :json
  r.table("feeds").run(@con).to_a.to_json
end

get "/feed/:id/posts" do
  content_type :json

  begin
    output = r.table("posts")
      .order_by(:index => r.desc("published"))
      .filter({feed: params["id"]}).run(@con)
  rescue
    return {success: false, err: "Failed to fetch posts"}.to_json
  end

  {success: true, feed: params["id"], posts: output.to_a}.to_json
end

delete "/feed/:id" do
  begin
    r.table("posts").filter({feed: params["id"]}).delete.run(@con)
    r.table("feeds").get(params["id"]).delete.run(@con)
  rescue
    return {success: false, err: "Failed to delete feed"}.to_json
  end

  {success: true}.to_json
end

get "/" do
  redirect "/index.html"
end

get "/refresh" do
  UpdateFeedsJob.new.async.perform nil
end

class Object
  def force_to_h
    Hash[instance_variables.map {|v| [v[1..-1], self[v[1..-1]]] }]   
  end
end


