require 'sinatra'
require 'slim'
require 'sinatra/reloader'
require 'sinatra/activerecord'
require 'redcarpet'
require './helpers/markdown.rb'
require './helpers/is_not_include_image?.rb'
require 'rack-flash'
# enable :sessions
use Rack::Flash
enable :sessions # これでダメな場合↓
# use Rack::Session::Cookie
# クッキー内のセッションデータはセッション秘密鍵(session secret)で署名されます。
# Sinatraによりランダムな秘密鍵が個別に生成されるらしい
# 個別で設定する場合は↓
# set :session_secret, 'super secret'

# database.ymlを読み込み
ActiveRecord::Base.configurations = YAML.load_file('database.yml')
# developmentを設定
ActiveRecord::Base.establish_connection(:development)
Time.zone = "Tokyo"
ActiveRecord::Base.default_timezone = :local

class Post < ActiveRecord::Base
  validates_presence_of :title, :body, :top_picture # 値が空じゃないか
  validates :title, length: { in: 1..75 }
  validates :body,  length: { in: 1..20000 }
  validates :top_picture, format: { with: /.*\.(jpg|png|jpeg)\z/,
                                    message: "is only jpg, jpeg, png" }
  # before_validation :file_check # save直前に実行される

  private
  # private
end

class Category < ActiveRecord::Base
end

get '/' do
  @category = Category.all
  slim :index
end

get '/articles/:id' do
  @post = Post.find(params[:id])
  @category = Category.where(cate_id: @post.cate_id)
  slim :articles
end

post '/article_post' do
  # 画像ファイル自体はモデルを持っていないため、存在チェックをコントローラで行う
  # params[:file]がnilの場合、params[:file][:filename]で例外が発生する
  # prevから投稿する場合、画像は保存してあるのでparams[:pic_name]にファイル名を格納してそれを使う
  if params[:file] || params[:pic_name]
    params[:pic_name] ? pic_name = params[:pic_name] : pic_name = params[:file][:filename]
    @post = Post.new(
      cate_id:     params[:cate_id],
      title:       params[:title],
      body:        params[:body],
      top_picture: pic_name)

    img_files = params[:article_img_files]
    if ((@post.body.scan(/!\[\S*\]\(\S*\)/).length == 0 && img_files.nil?) \
      || is_not_include_image?(@post.body, img_files)) && params[:back].nil? && @post.save
      # top画像ファイル保存
      File.open("public/img/#{@post.top_picture}", 'wb') { |f| f.write(params[:file][:tempfile].read) }
      # 記事内画像があればそれも保存
      if img_files
        img_files.each do |img|
          File.open("public/img/#{img[:filename]}", 'wb') { |f| f.write(img[:tempfile].read) }
        end
      end
      flash[:notice] = "投稿完了"
      redirect "/articles/#{@post.id}"
    else
      # プレビュー画面から修正に戻った場合
      if params[:back]
        File.delete("public/img/#{@post.top_picture}") if File.exist?("public/img/#{@post.top_picture}")
        if session[:img_files]
          session[:img_files].each do |img_name|
            File.delete("public/img/#{img_name}") if File.exist?("public/img/#{img_name}")
          end
        end
      end
      @category = Category.all
      # エラーメッセージを表示させたいのでレンダーする
      slim :index
    end
  else
    redirect '/'
  end
end

post '/article_prev' do
  if params[:file]
    @post = Post.new(
      id:          Post.count + 1, # ダミー
      cate_id:     params[:cate_id],
      title:       params[:title],
      body:        params[:body],
      top_picture: params[:file][:filename])

    img_files = params[:article_img_files]
    # プレビューなので保存しないでvalid?だけチェックし、画像は保存する
    # 画像タグがない かつ 画像がなければ画像の検査はしない　それ以外の場合は全て画像を検査する
    if is_not_include_image?(@post.body, img_files) && @post.valid?
      File.open("public/img/#{@post.top_picture}", 'wb') { |f| f.write(params[:file][:tempfile].read) }
      if img_files
        # 修正に戻った場合、記事内画像ファイルの名前をセッションで保持し、削除する
        img_name_ary = []
        img_files.each do |img|
          File.open("public/img/#{img[:filename]}", 'wb') { |f| f.write(img[:tempfile].read) }
          img_name_ary << img[:filename]
        end
        session[:img_files] = img_name_ary
      end
      @category = Category.where(cate_id: @post.cate_id)
      slim :article_prev
    else
      # エラーメッセージを表示させたいのでレンダリング
      @category = Category.all
      slim :index
    end
  else
    redirect '/'
  end
end
