//
//  ChatMessageMediaCell.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 图片消息横向展示 cell
//
//

import UIKit
import SnapKit
import Kingfisher

final class ChatMessageMediaCell: ChatBaseBubbleCell {
    static let reuseIdentifier = "ChatMessageMediaCell"

    private let singleMediaSize: CGFloat = 150
    private let multiMediaSize: CGFloat = 80
    private var imageItems: [MediaContent] = []
    private var collectionWidthConstraint: Constraint?
    private var collectionHeightConstraint: Constraint?

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        layout.itemSize = CGSize(width: singleMediaSize, height: singleMediaSize)

        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.alwaysBounceHorizontal = true
        view.alwaysBounceVertical = false
        view.contentInset = .zero
        view.contentInsetAdjustmentBehavior = .never
        view.dataSource = self
        view.delegate = self
        view.register(ChatMediaImageItemCell.self, forCellWithReuseIdentifier: ChatMediaImageItemCell.reuseIdentifier)
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageItems = []
        bubbleView.isHidden = true
        collectionView.setContentOffset(.zero, animated: false)
        collectionView.reloadData()
        collectionWidthConstraint?.update(offset: singleMediaSize)
        collectionHeightConstraint?.update(offset: singleMediaSize)
    }

    func configure(with message: Message) {
        configureBase(message: message)
        imageItems = message.mediaContents.filter { $0.type == .image }
        setBubbleHidden(imageItems.isEmpty)
        bubbleView.isHidden = true

        let spacing: CGFloat = 8
        let count = imageItems.count
        let itemSize = count > 1 ? multiMediaSize : singleMediaSize

        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            if layout.itemSize.width != itemSize || layout.itemSize.height != itemSize {
                layout.itemSize = CGSize(width: itemSize, height: itemSize)
                layout.invalidateLayout()
            }
        }

        collectionHeightConstraint?.update(offset: itemSize)

        let contentWidth = itemSize * CGFloat(count) + spacing * CGFloat(max(0, count - 1))
        let maxContentWidth = max(0, UIScreen.main.bounds.width - 32)
        let visibleWidth = max(itemSize, min(contentWidth, maxContentWidth))
        collectionWidthConstraint?.update(offset: visibleWidth)
        collectionView.reloadData()
    }

    private func setupViews() {
        bubbleContentView.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.leading.equalToSuperview()
            collectionHeightConstraint = make.height.equalTo(singleMediaSize).constraint
            make.bottom.trailing.equalToSuperview()
            collectionWidthConstraint = make.width.equalTo(singleMediaSize).priority(.required).constraint
        }
    }
}

extension ChatMessageMediaCell: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        imageItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ChatMediaImageItemCell.reuseIdentifier,
            for: indexPath
        ) as? ChatMediaImageItemCell else {
            return UICollectionViewCell()
        }
        guard indexPath.item < imageItems.count else { return cell }
        cell.configure(with: imageItems[indexPath.item])
        return cell
    }
}

private final class ChatMediaImageItemCell: UICollectionViewCell {
    static let reuseIdentifier = "ChatMediaImageItemCell"

    private lazy var imageContainer: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        view.backgroundColor = UIColor.black.withAlphaComponent(0.04)
        return view
    }()

    private lazy var imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.backgroundColor = .clear
        return view
    }()

    private var currentKey: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear
        contentView.addSubview(imageContainer)
        imageContainer.addSubview(imageView)
        imageContainer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        contentView.backgroundColor = .clear
        contentView.addSubview(imageContainer)
        imageContainer.addSubview(imageView)
        imageContainer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        currentKey = nil
        imageView.kf.cancelDownloadTask()
        imageView.image = nil
    }

    func configure(with media: MediaContent) {
        let key = ChatMediaCacheKey.imageKey(for: media)
        if currentKey == key { return }
        currentKey = key
        let provider = RawImageDataProvider(data: media.data, cacheKey: key)
        imageView.kf.setImage(with: .provider(provider), options: [.cacheOriginalImage, .backgroundDecode])
    }
}
