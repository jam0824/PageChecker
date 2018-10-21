require 'net/http'
require 'net/https'
require 'open-uri'
require 'nokogiri'

class PageChecker
    #スクレイピングしたURLが有効か確認
    def check_url?(url, domain)
        url = url.to_s
        return_value = true
        if url.include?('#') || url.include?('javascript:')
            #ページ内処理の場合
            return_value = false
        elsif url == ""
            #空行の場合
            return_value = false
        elsif url.include?('mailto')
            #mailの場合
            return_value = false
        else
            begin
                if URI.parse(url).host != nil && URI.parse(url).host != domain
                    #他ドメインの場合
                    return_value = false
                else
                    return_value = true
                end
            rescue => exception
                process_exception(url)
                return_value = true
            end
        end
        return return_value
    end

    #urlがファイル指定だった場合の処理
    def delete_file_name(url, domain)
        return url if url[url.length - 1] == '/'
        file_name = File.basename(url)
        if file_name != domain
            #ファイル名がドメインではなかったら処理
            url = url.gsub(/#{file_name}/, '')
        end
        return url
    end

    #urlを絶対パスに変更
    def make_url(base_url, target_url, domain)
        if target_url[0, 4] == 'http'
            return target_url
        elsif target_url[0, 1] == '/'
            return URI.parse(base_url).scheme + '://' + domain + target_url
        else #相対パス結合の場合
            base_url = delete_file_name(base_url, domain)
            path = File.expand_path(target_url, base_url)
            pwd = Dir.pwd + '/'
            path = path.gsub(/#{pwd}/, '')
            path = path.gsub(/:\//, '://')
            return path
        end
    end

    #statusとbodyを取得
    def get_html_source(current_url)
        begin
            url = URI.parse(current_url)
        rescue => exception
            process_exception(current_url)
            return '9999', ''
        end
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true if url.port == 443
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE if url.port == 443
        res = http.get(current_url)
        return res.code, res.body
    end

    #該当ページのスクレイピング
    def add_all_url_in_site(current_url, domain, stack, source)
        doc = Nokogiri::HTML(source)
        doc.xpath('//a').each do |item|
            if check_url?(item[:href], domain)
                stack.unshift(
                    make_url(current_url, item[:href], domain)
                )
            end
        end
        return stack
    end

    #簡易ドメインチェック
    def check_domain?(url, domain)
        begin
            if URI.parse(url).host != domain
                return false
            else
                return true
            end
        rescue => exception
            process_exception(url)
            return false
        end
    end

    #例外処理
    def process_exception(url)
        p "Analysis error : #{url}"
        @error_stack.push('9999 :' + url)
    end

    def show_error(stack)
        if stack.length == 0
            p "No Error" 
            return
        else
           stack.each do |item|
                p item
           end
        end
    end
   
    #1.スタックの上からURLを一つ取り出す
    #2-1.該当URLがチェック済みなら終了
    #2-2.該当URLが他ドメインだったら終了
    #3.該当URLのステータスとボディを取得
    #4.ステータスがリダイレクト、エラーだったら終了
    #5.該当ページをスクレイピングしてa hrefを抜き、スタックに積む
    def main(url)
        @error_stack = []

        stack = []
        finished_stack = []
        domain = URI.parse(url).host
        stack.push(url)

        stack.each do |current_url|
            next if finished_stack.include?(current_url)
            finished_stack.push(current_url)
            next if !check_domain?(current_url, domain)
            
            status, source = get_html_source(current_url)
            p "#{status} : #{current_url}"
            if status.to_i >= 300 then
                if status.to_i >= 400 then
                    @error_stack.push(status + ':' + current_url)
                end
                next
            end
            stack = add_all_url_in_site(
                current_url, 
                domain, 
                stack, 
                source
            ) if source != ""
        end

        p "**********"
        p "finish!"
        p "**********"
        show_error(@error_stack)

    end
end

