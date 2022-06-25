//
//  GithubSearchReactor.swift
//  P_ReactorKit
//
//  Created by 임지성 on 2022/06/25.
//

import Foundation
import RxSwift
import RxCocoa
import ReactorKit

final class GithubSearchViewReactor: Reactor {
    var initialState: State = State()
    
    // View로부터 받을 액션
    enum Action {
        case updateQuery(String?)
        case loadNextPage
    }
    
    // 액션을 받은 경우 해야될 작업 단위
    enum Mutation {
        case setQuery(String?)
        case setRepos([String], nextPage: Int?)
        case appendRepos([String], nextPage: Int?)
        case setLoadingNextPage(Bool)
    }
    
    // 현재 상태 (ex. 다음 페이지 유무)
    struct State {
        var query: String?
        var repos: [String] = []
        var nextPage: Int?
        var isLoadingNextPage: Bool = false
    }
    
    // mutate 실행후 실행, 현재 상태(State)와 작업 단위(Mutation)를 받아 작업 결과가 적용된 최종 상태를 반환
    func reduce(state: State, mutation: Mutation) -> State {
        switch mutation {
        case let .setQuery(query):
            var newState = state
            newState.query = query
            return newState
        case let .setRepos(repos, nextPage: nextPage):
            var newState = state
            newState.repos = repos
            newState.nextPage = nextPage
            return newState
        case let .appendRepos(repos, nextPage: nextPage):
            var newState = state
            newState.repos.append(contentsOf: repos)
            newState.nextPage = nextPage
            return newState
        case let .setLoadingNextPage(isLoadingNextPage):
            var newState = state
            newState.isLoadingNextPage = isLoadingNextPage
            return newState
        }
    }
    
    // Action이 들어온 경우, 어떤 처리를 할것인지 Mutation에서 정의한 작업 단위들을 사용하여 Observable로 방출
    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case let .updateQuery(query):
            return Observable.concat([
                // 현재 query 세팅
                Observable.just(Mutation.setQuery(query)),
                
                // 쿼리로 api 호출 후 repo 세팅
                self.search(query: query, page: 1)
                    .take(until: self.action.filter(Action.isUpdateQueryAction))
                    .map { Mutation.setRepos($0, nextPage: $1) }
            ])
        case .loadNextPage:
            guard !self.currentState.isLoadingNextPage else { return .empty() } // 중복 요청 방지
            guard let page = self.currentState.nextPage else { // 다음 페이지 유무 확인
                return .empty()
            }
            
            return Observable.concat([
                // 다음 페이지 로딩중으로 상태 변경하여 중복 요청 방지
                Observable.just(Mutation.setLoadingNextPage(true)),
                
                // 요청
                self.search(query: self.currentState.query, page: page)
                    .take(until: self.action.filter(Action.isUpdateQueryAction))
                    .map { Mutation.appendRepos($0, nextPage: $1) },
                
                // 요청 끝났으면 로딩중 아닌 상태로 변경
                Observable.just(Mutation.setLoadingNextPage(false))
            ])
        }
    }
    
    func search(
        query: String?,
        page: Int
    ) -> Observable<(repos: [String], nextPage: Int?)> {
        guard let url = url(query: query, page: page) else {
            return .just(([], nil))
        }
        
        return URLSession.shared.rx.json(url: url)
            .map { json -> ([String], Int?) in
                guard let dict = json as? [String: Any] else {
                    return ([], nil)
                }
                
                guard let items = dict["items"] as? [[String: Any]] else {
                    return ([], nil)
                }
                
                let repos = items.compactMap { 
                    $0["full_name"] as? String
                }
                
                let nextPage = repos.isEmpty ? nil : page + 1
                
                return (repos, nextPage)
            }
            .do(onError: { err in
                if case let .some(.httpRequestFailed(response, _)) = err as? RxCocoaURLError, response.statusCode == 403 {
                    print("⚠️ GitHub API rate limit exceeded. Wait for 60 seconds and try again.")
                }
            })
            .catchAndReturn(([], nil))
    }
    
    private func url(query: String?, page: Int, react: String = "react") -> URL? {
        guard let query = query else {
            return nil
        }

        let queryItem = URLQueryItem(name: "q", value: "\(query)")
        let pageItem = URLQueryItem(name: "page", value: "\(page)")

        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "api.github.com"
        urlComponents.path = "/search/repositories"
        urlComponents.queryItems = [queryItem, pageItem]

        return urlComponents.url
    }
}

extension GithubSearchViewReactor.Action {
    static func isUpdateQueryAction(_ action: GithubSearchViewReactor.Action) -> Bool {
        if case .updateQuery = action {
            return true
        } else {
            return false
        }
    }
}
