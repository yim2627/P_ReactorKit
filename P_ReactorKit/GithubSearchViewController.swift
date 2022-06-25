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
        navigationItem.searchController = searchViewController
    }

    func bind(reactor: GithubSearchViewReactor) {
        
    }

}

