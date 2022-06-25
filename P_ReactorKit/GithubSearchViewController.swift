//
//  ViewController.swift
//  P_ReactorKit
//
//  Created by 임지성 on 2022/06/25.
//

import UIKit
import SafariServices

import RxSwift
import RxCocoa
import ReactorKit

class GithubSearchViewController: UIViewController, StoryboardView {
    @IBOutlet weak var tableView: UITableView!
    let searchViewController = UISearchController(searchResultsController: nil)
    
    var disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.verticalScrollIndicatorInsets.top = tableView.contentInset.top
        searchViewController.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = searchViewController
    }

    func bind(reactor: GithubSearchViewReactor) {
        searchViewController.searchBar.rx.text
            .throttle(.microseconds(300), scheduler: MainScheduler.instance)
            .map { Reactor.Action.updateQuery($0) }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        reactor.state.map { $0.repos }
            .bind(to: tableView.rx.items(cellIdentifier: "cell")) { indexPath, repo, cell in
                cell.textLabel?.text = repo
            }
            .disposed(by: disposeBag)
        
        tableView.rx.itemSelected
            .subscribe(onNext: { [weak self, weak reactor] indexPath in
                self?.view.endEditing(true)
                self?.tableView.deselectRow(at: indexPath, animated: false)
                guard let repo = reactor?.currentState.repos[indexPath.row],
                      let url = URL(string: "https://github.com/\(repo)") else {
                    return
                }
                
                let vc = SFSafariViewController(url: url)
                self?.searchViewController.present(vc, animated: true)
            })
            .disposed(by: disposeBag)
    }

}

