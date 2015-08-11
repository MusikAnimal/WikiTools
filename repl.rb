module Repl

  class Session
    require 'mysql2'

    def initialize(username, password, host, db, port)
      @client = Mysql2::Client.new(
        host: host,
        username: username,
        password: password,
        database: db,
        port: port
      )
      @db = db
    end

    # COUNTERS
    def countArticlesCreated(userName)
      count("SELECT count(*) FROM #{@db}.page JOIN #{@db}.revision_userindex ON page_id = rev_page " +
        "WHERE rev_user_text = \"#{userName}\" AND rev_timestamp > 1 AND rev_parent_id = 0 " +
        "AND page_namespace = 0 AND page_is_redirect = 0;")
    end

    def countEdits(opts)
      opts[:count] = true
      getEdits(opts)
    end

    # GETTERS
    def getArticlesCreated(userName)
      query = "SELECT page_title, rev_timestamp AS timestamp FROM #{@db}.page JOIN #{@db}.revision_userindex ON page_id = rev_page " +
        "WHERE rev_user_text = \"#{userName}\" AND rev_timestamp > 1 AND rev_parent_id = 0 " +
        "AND page_namespace = 0 AND page_is_redirect = 0;"
      puts query
      res = @client.query(query)
      articles = []
      res.each do |result|
        result["timestamp"] = DateTime.parse(result["timestamp"])
        articles << result
      end
      articles
    end

    def getEdits(opts)
      opts = {
        namespace: nil,
        nonAutomated: nil,
        tool: nil,
        limit: 50,
        offset: 0,
        count: false
      }.merge(opts)

      query = "SELECT " +
        (opts[:count] ? "COUNT(*) " : "#{revAttrs} ") +
        "FROM #{@db}.page " +
        "JOIN enwiki_p.revision_userindex ON page_id = rev_page " +
        "WHERE rev_user_text = \"#{opts[:username]}\" "+
        (opts[:namespace] ? "AND page_namespace = #{opts[:namespace]} " : "") +
        (!opts[:nonAutomated].nil? ? "AND rev_comment #{"NOT " if opts[:nonAutomated]}RLIKE \"#{toolRegexes(opts[:tool]).join("|")}\" " : "") +
        (!opts[:count] ? "ORDER BY rev_id DESC LIMIT #{opts[:limit]} OFFSET #{opts[:offset]}" : "")

      opts[:count] ? count(query) : get(query)
    end

    private

    def count(query)
      puts query
      @client.query(query).first.values[0].to_i
    end

    def get(query)
      puts query
      @client.query(query)
    end

    def revAttrs
      ["page_title", "page_len", "rev_id", "rev_page", "rev_timestamp", "rev_minor_edit", "rev_comment", "rev_len"].join(", ")
    end

    def toolRegexes(index)
      tools = [
        "^Reverted edits by .* \(talk\) to last version by .*", # Generic revert
        "WP:HG",                                                # Huggle
        "WP:TW",                                                # Twinkle
        "WP:STiki",                                             # STiki
        "Wikipedia:Igloo",                                      # Igloo
        "Wikipedia:Tools\/Navigation_popups|popups",            # Popups
        "WP:AFCH",                                              # AFCH
        "Wikipedia:AWB|WP:AWB",                                 # AWB
        "WP:CLEANER",                                           # WP Cleaner
        "WP:HOTCAT|WP:HC",                                      # HotCat
        "WP:REFILL",                                            # reFill
        "User:Jfmantis/WikiPatroller"                           # WikiPatroller
      ]
      if index
        [tools[index]]
      else
        tools
      end
    end
  end

end