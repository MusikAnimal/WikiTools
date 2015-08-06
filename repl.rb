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

    def countArticlesCreated(userName)
      count("SELECT count(*) FROM #{@db}.page JOIN #{@db}.revision_userindex ON page_id = rev_page " +
        "WHERE rev_user_text = \"#{userName}\" AND rev_timestamp > 1 AND rev_parent_id = 0 " +
        "AND page_namespace = 0 AND page_is_redirect = 0;")
    end

    def countAutomatedEdits(userName, nonAutomated = false, tool = nil)
      count("SELECT count(*) FROM #{@db}.revision_userindex WHERE rev_user_text=\"#{userName}\" " +
        "AND rev_comment#{" NOT" if nonAutomated} RLIKE \"#{toolRegexes(tool).join("|")}\";")
    end

    def countAutomatedNamespaceEdits(userName, namespace, nonAutomated = false, tool = nil)
      count("SELECT count(*) FROM #{@db}.page JOIN #{@db}.revision_userindex ON page_id = rev_page " +
        "WHERE rev_user_text = \"#{userName}\" AND page_namespace = #{namespace} " +
        "AND rev_comment#{" NOT" if nonAutomated} RLIKE \"#{toolRegexes(tool).join("|")}\";")
    end

    def countNamespaceEdits(userName, namespace = 0)
      count("SELECT count(*) FROM #{@db}.page JOIN #{@db}.revision_userindex ON page_id = rev_page " +
        "WHERE rev_user_text = \"#{userName}\" AND page_namespace = #{namespace};")
    end

    def countNonAutomatedEdits(userName)
      countAutomatedEdits(userName, true)
    end

    def countNonAutomatedNamespaceEdits(userName, namespace)
      countAutomatedNamespaceEdits(userName, namespace, true)
    end

    def countToolEdits(userName, tool)
      countAutomatedEdits(userName, false, tool)
    end

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

    def getNonAutomatedEdits(userName)
      # SELECT rev_id, rev_timestamp, rev_minor_edit, rev_comment FROM enwiki_p.page
      #   JOIN enwiki_p.revision_userindex ON page_id = rev_page
      #   WHERE rev_user_text = "Roches" AND page_namespace = 0
      #   AND rev_comment NOT RLIKE "^Reverted edits by .* (talk) to last version by .*|WP:HG|WP:TW|WP:STiki|Wikipedia:Igloo|Wikipedia:Tools/Navigation_popups|popups|WP:AFCH|Wikipedia:AWB|WP:AWB|WP:CLEANER|WP:HOTCAT|WP:HC|WP:REFILL|User:Jfmantis/WikiPatroller"
      #   LIMIT 500;
    end

    private

    def count(query)
      puts query
      @client.query(query).first.values[0].to_i
    end

    # FIXME: this can just return an array and it will work with toolRegexes[index]
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