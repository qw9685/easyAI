//
//  ChatInputBarViewController.swift
//  EasyAI
//
//  创建于 2026
//  主要功能：
//  - 输入栏 UI 与图片选择
//  - 驱动发送按钮状态
//
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import PhotosUI

final class ChatInputBarViewController: UIViewController {
    private let viewModel: ChatViewModel
    private let actionHandler: ((ChatViewModel.Action) -> Void)?
    private let input = ChatInputViewModel()

    private let disposeBag = DisposeBag()

    private let topDivider = UIView()
    private let rootBackground = UIView()

    private let rowStack = UIStackView()
    private let photoButton = UIButton(type: .system)
    private let sendButton = UIButton(type: .system)
    private var sendEnabledImage: UIImage?
    private var sendDisabledImage: UIImage?
    private var stopBaseImage: UIImage?
    private let sendButtonSize: CGFloat = 32

    private let inputContainer = UIView()
    private let selectedImagesCollection: UICollectionView
    private var selectedImagesHeightConstraint: Constraint?

    private let textView = UITextView()
    private var textViewHeightConstraint: Constraint?
    private let clearTextButton = UIButton(type: .system)
    private let micButton = UIButton(type: .system)
    private let micIndicator = UIView()
    private let trailingStack = UIStackView()

    private let maxLines: Int = 5
    private let thumbSize: CGFloat = 48
    private let thumbSpacing: CGFloat = 8
    private let textMinHeight: CGFloat = 20
    private var cachedPhotoPicker: PHPickerViewController?
    private var isRecognizing: Bool = false
    private var recognitionBaseText: String = ""
    private let speechManager = SpeechToTextManager.shared

    init(viewModel: ChatViewModel, actionHandler: ((ChatViewModel.Action) -> Void)? = nil) {
        self.viewModel = viewModel
        self.actionHandler = actionHandler

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = thumbSpacing
        layout.minimumInteritemSpacing = thumbSpacing
        layout.itemSize = CGSize(width: thumbSize, height: thumbSize)
        self.selectedImagesCollection = UICollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(nibName: nil, bundle: nil)
        input.actionHandler = actionHandler
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bind()
        updateUI()
        warmUpPhotoLibrary()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async { [weak self] in
            self?.warmUpPhotoPickerIfNeeded()
        }
    }

    private func warmUpPhotoLibrary() {
        // 预热 Photos 框架/权限状态，减少首次弹出 PHPicker 的卡顿
        if #available(iOS 14, *) {
            _ = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        } else {
            _ = PHPhotoLibrary.authorizationStatus()
        }
    }

    private func warmUpPhotoPickerIfNeeded() {
        guard cachedPhotoPicker == nil else { return }
        cachedPhotoPicker = makePhotoPicker(selectionLimit: 1)
    }

    private func makePhotoPicker(selectionLimit: Int) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = selectionLimit
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        return picker
    }

    private func setupUI() {
        view.backgroundColor = .clear

        topDivider.backgroundColor = AppTheme.border
        view.addSubview(topDivider)
        topDivider.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(1 / UIScreen.main.scale)
        }

        rootBackground.backgroundColor = AppTheme.surface
        rootBackground.layer.cornerRadius = AppTheme.inputCornerRadius
        rootBackground.layer.borderColor = AppTheme.border.cgColor
        rootBackground.layer.borderWidth = AppTheme.borderWidth / UIScreen.main.scale
        rootBackground.layer.shadowColor = AppTheme.shadow.cgColor
        rootBackground.layer.shadowOpacity = 1
        rootBackground.layer.shadowRadius = AppTheme.shadowRadius
        rootBackground.layer.shadowOffset = AppTheme.shadowOffset
        view.addSubview(rootBackground)
        rootBackground.snp.makeConstraints { make in
            make.top.equalTo(topDivider.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = 12
        rootBackground.addSubview(rowStack)
        rowStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(12)
        }

        configurePhotoButton()
        rowStack.addArrangedSubview(photoButton)

        configureInputContainer()
        rowStack.addArrangedSubview(inputContainer)

        configureSendButton()
        rowStack.addArrangedSubview(sendButton)

        rowStack.setCustomSpacing(12, after: photoButton)
        rowStack.setCustomSpacing(12, after: inputContainer)
    }

    func applyTheme() {
        topDivider.backgroundColor = AppTheme.border
        rootBackground.backgroundColor = AppTheme.surface
        rootBackground.layer.cornerRadius = AppTheme.inputCornerRadius
        rootBackground.layer.borderColor = AppTheme.border.cgColor
        rootBackground.layer.borderWidth = AppTheme.borderWidth / UIScreen.main.scale
        rootBackground.layer.shadowColor = AppTheme.shadow.cgColor
        rootBackground.layer.shadowOpacity = 1
        rootBackground.layer.shadowRadius = AppTheme.shadowRadius
        rootBackground.layer.shadowOffset = AppTheme.shadowOffset

        photoButton.tintColor = AppTheme.textSecondary
        clearTextButton.tintColor = AppTheme.textTertiary
        textView.textColor = AppTheme.textPrimary
        micButton.tintColor = isRecognizing ? AppTheme.accent : AppTheme.textSecondary
        micIndicator.backgroundColor = AppTheme.accent

        let radius: CGFloat = sendButtonSize / 2
        sendButton.setBackgroundImage(Self.circleBackgroundImage(size: sendButtonSize, color: AppTheme.accent, cornerRadius: radius), for: .normal)
        sendButton.setBackgroundImage(Self.circleBackgroundImage(size: sendButtonSize, color: AppTheme.border, cornerRadius: radius), for: .disabled)
        sendButton.setBackgroundImage(Self.circleBackgroundImage(size: sendButtonSize, color: AppTheme.accent2, cornerRadius: radius), for: .highlighted)

        if let placeholder = textView.viewWithTag(999) as? UILabel {
            placeholder.textColor = AppTheme.textTertiary
        }
        updateUI()
    }

    private func configurePhotoButton() {
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
        photoButton.setImage(UIImage(systemName: "photo", withConfiguration: config), for: .normal)
        photoButton.tintColor = AppTheme.textSecondary
        photoButton.addTarget(self, action: #selector(didTapPhoto), for: .touchUpInside)
        photoButton.snp.makeConstraints { make in
            make.width.height.equalTo(28)
        }
    }

    private func configureSendButton() {
        let sendConfig = UIImage.SymbolConfiguration(pointSize: 17, weight: .bold)
        let stopConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .black)
        let base = UIImage(systemName: "arrow.up", withConfiguration: sendConfig)
        let stopBase = UIImage(systemName: "stop.fill", withConfiguration: stopConfig)
        sendEnabledImage = base?.withTintColor(.white, renderingMode: .alwaysOriginal)
        sendDisabledImage = base?.withTintColor(UIColor.white.withAlphaComponent(0.55), renderingMode: .alwaysOriginal)
        stopBaseImage = stopBase
        
        sendButton.setImage(sendEnabledImage, for: .normal)
        sendButton.setImage(sendDisabledImage, for: .disabled)
        
        let radius: CGFloat = sendButtonSize / 2
        sendButton.setBackgroundImage(Self.circleBackgroundImage(size: sendButtonSize, color: AppTheme.accent, cornerRadius: radius), for: .normal)
        sendButton.setBackgroundImage(Self.circleBackgroundImage(size: sendButtonSize, color: AppTheme.border, cornerRadius: radius), for: .disabled)
        sendButton.setBackgroundImage(Self.circleBackgroundImage(size: sendButtonSize, color: AppTheme.accent2, cornerRadius: radius), for: .highlighted)

        sendButton.layer.cornerRadius = radius
        sendButton.layer.masksToBounds = true
        

        sendButton.imageView?.layer.shadowColor = UIColor.black.withAlphaComponent(0.22).cgColor
        sendButton.imageView?.layer.shadowOpacity = 1.0
        sendButton.imageView?.layer.shadowRadius = 2
        sendButton.imageView?.layer.shadowOffset = CGSize(width: 0, height: 1)

        sendButton.addTarget(self, action: #selector(didTapSend), for: .touchUpInside)
        sendButton.snp.makeConstraints { make in
            make.width.height.equalTo(sendButtonSize)
        }
    }

    private static func circleBackgroundImage(size: CGFloat, color: UIColor, cornerRadius: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            context.cgContext.setFillColor(color.cgColor)
            context.cgContext.addPath(path.cgPath)
            context.cgContext.fillPath()
        }
        return image.resizableImage(
            withCapInsets: UIEdgeInsets(top: cornerRadius, left: cornerRadius, bottom: cornerRadius, right: cornerRadius)
        )
    }

    private func configureInputContainer() {
        inputContainer.backgroundColor = AppTheme.surface
        inputContainer.layer.cornerRadius = AppTheme.controlCornerRadius
        inputContainer.layer.borderColor = AppTheme.border.cgColor
        inputContainer.layer.borderWidth = AppTheme.borderWidth / UIScreen.main.scale
        inputContainer.layer.shadowColor = AppTheme.shadow.cgColor
        inputContainer.layer.shadowOpacity = 1
        inputContainer.layer.shadowRadius = 12
        inputContainer.layer.shadowOffset = CGSize(width: 0, height: 3)
        inputContainer.clipsToBounds = false

        inputContainer.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(48)
        }

        selectedImagesCollection.backgroundColor = .clear
        selectedImagesCollection.showsHorizontalScrollIndicator = false
        selectedImagesCollection.clipsToBounds = false
        selectedImagesCollection.dataSource = self
        selectedImagesCollection.delegate = self
        selectedImagesCollection.register(
            ChatInputSelectedImageCell.self,
            forCellWithReuseIdentifier: ChatInputSelectedImageCell.reuseIdentifier
        )
        inputContainer.addSubview(selectedImagesCollection)
        selectedImagesCollection.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(12)
            selectedImagesHeightConstraint = make.height.equalTo(0).constraint
        }

        textView.backgroundColor = .clear
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.textColor = AppTheme.textPrimary
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.lineBreakMode = .byCharWrapping
        textView.textContainer.widthTracksTextView = true
        textView.isScrollEnabled = false
        textView.delegate = self
        inputContainer.addSubview(textView)
        textView.snp.makeConstraints { make in
            make.top.equalTo(selectedImagesCollection.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().inset(76)
            make.bottom.equalToSuperview().inset(12)
            textViewHeightConstraint = make.height.equalTo(textMinHeight).priority(.high).constraint
        }

        configureTrailingControls()

        // placeholder
        let placeholder = UILabel()
        placeholder.text = "输入消息..."
        placeholder.font = textView.font
        placeholder.textColor = AppTheme.textTertiary
        placeholder.numberOfLines = 1
        placeholder.tag = 999
        textView.addSubview(placeholder)
        placeholder.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
        }
    }

    private func bind() {
        // Input → UI
        input.inputTextObservable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] text in
                guard let self else { return }
                if self.textView.text != text {
                    self.textView.text = text
                }
                self.updatePlaceholder()
                self.recalcTextHeight()
                self.updateUI()
            })
            .disposed(by: disposeBag)

        input.selectedImagesObservable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                guard let self else { return }
                self.updateSelectedImagesBarVisibility()
                self.selectedImagesCollection.collectionViewLayout.invalidateLayout()
                self.selectedImagesCollection.reloadData()
                self.selectedImagesCollection.layoutIfNeeded()
                self.updateUI()
            })
            .disposed(by: disposeBag)

        // Chat state → UI
        viewModel.isLoadingObservable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.updateUI()
            })
            .disposed(by: disposeBag)
    }

    private func updateUI() {
        clearTextButton.isHidden = input.inputText.isEmpty

        let isLoading = viewModel.isLoading
        let isDisabled = input.isSendDisabled(isChatLoading: isLoading)
        sendButton.isEnabled = isLoading ? true : !isDisabled
        if isLoading {
            let radius: CGFloat = sendButtonSize / 2
            sendButton.setBackgroundImage(
                Self.circleBackgroundImage(size: sendButtonSize, color: AppTheme.surface, cornerRadius: radius),
                for: .normal
            )
            sendButton.setBackgroundImage(
                Self.circleBackgroundImage(size: sendButtonSize, color: AppTheme.surfaceAlt, cornerRadius: radius),
                for: .highlighted
            )
            sendButton.layer.borderWidth = 1.2
            sendButton.layer.borderColor = AppTheme.accent.cgColor
            let stopImage = stopBaseImage?.withTintColor(AppTheme.accent, renderingMode: .alwaysOriginal)
            sendButton.setImage(stopImage, for: .normal)
        } else {
            let radius: CGFloat = sendButtonSize / 2
            sendButton.setBackgroundImage(Self.circleBackgroundImage(size: sendButtonSize, color: AppTheme.accent, cornerRadius: radius), for: .normal)
            sendButton.setBackgroundImage(Self.circleBackgroundImage(size: sendButtonSize, color: AppTheme.border, cornerRadius: radius), for: .disabled)
            sendButton.setBackgroundImage(Self.circleBackgroundImage(size: sendButtonSize, color: AppTheme.accent2, cornerRadius: radius), for: .highlighted)
            sendButton.layer.borderWidth = 0
            sendButton.layer.borderColor = UIColor.clear.cgColor
            sendButton.setImage(isDisabled ? sendDisabledImage : sendEnabledImage, for: .normal)
        }

        let hasAny = !input.selectedImages.isEmpty
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
        photoButton.setImage(UIImage(systemName: hasAny ? "photo.fill" : "photo", withConfiguration: config), for: .normal)
        photoButton.tintColor = hasAny ? AppTheme.accent : AppTheme.textSecondary
        photoButton.isEnabled = input.remainingSelectionLimit > 0
        photoButton.alpha = photoButton.isEnabled ? 1.0 : 0.4

        micButton.isEnabled = !viewModel.isLoading
        micButton.alpha = micButton.isEnabled ? 1.0 : 0.4
    }

    private func updateSelectedImagesBarVisibility() {
        let shouldShow = !input.selectedImages.isEmpty
        if shouldShow {
            selectedImagesCollection.isHidden = false
        }
        selectedImagesHeightConstraint?.update(offset: shouldShow ? thumbSize : 0)
        if !shouldShow {
            selectedImagesCollection.isHidden = true
        }
        view.layoutIfNeeded()
    }

    private func updatePlaceholder() {
        if let placeholder = textView.viewWithTag(999) as? UILabel {
            placeholder.isHidden = !textView.text.trimmingCharacters(in: .newlines).isEmpty
        }
    }

    private func recalcTextHeight() {
        guard let font = textView.font else { return }
        let lineHeight = font.lineHeight
        let maxHeight = lineHeight * CGFloat(maxLines)
        let width = max(textView.bounds.width, 1)
        let target = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        let clamped = max(textMinHeight, min(target, maxHeight))
        textView.isScrollEnabled = target > maxHeight
        textViewHeightConstraint?.update(offset: clamped)
        view.layoutIfNeeded()
    }

    @objc private func didTapClearText() {
        input.clearText()
    }

    @objc private func didTapSend() {
        stopRecognitionIfNeeded()
        input.send(chatViewModel: viewModel)
    }

    @objc private func didTapPhoto() {
        stopRecognitionIfNeeded()
        let remaining = input.remainingSelectionLimit
        guard remaining > 0 else { return }
        // PHPickerViewController.configuration 是只读的；selectionLimit 需要在创建时确定。
        // 这里每次点击都新建 picker，但首次创建成本已通过 warmUpPhotoPickerIfNeeded 提前支付。
        let picker = makePhotoPicker(selectionLimit: remaining)

        view.endEditing(true)
        DispatchQueue.main.async { [weak self] in
            self?.present(picker, animated: true)
        }
    }
}

private extension ChatInputBarViewController {
    func configureTrailingControls() {
        trailingStack.axis = .horizontal
        trailingStack.alignment = .center
        trailingStack.spacing = 6
        inputContainer.addSubview(trailingStack)
        trailingStack.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(12)
            make.top.equalTo(textView.snp.top).offset(1)
            make.height.equalTo(22)
        }

        clearTextButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clearTextButton.tintColor = AppTheme.textTertiary
        clearTextButton.addTarget(self, action: #selector(didTapClearText), for: .touchUpInside)
        clearTextButton.snp.makeConstraints { make in
            make.width.height.equalTo(22)
        }

        micButton.setImage(UIImage(systemName: "mic"), for: .normal)
        micButton.tintColor = AppTheme.textSecondary
        micButton.addTarget(self, action: #selector(didTapMic), for: .touchUpInside)
        micButton.snp.makeConstraints { make in
            make.width.height.equalTo(22)
        }

        micIndicator.backgroundColor = AppTheme.accent
        micIndicator.layer.cornerRadius = 3
        micIndicator.isHidden = true
        micIndicator.snp.makeConstraints { make in
            make.width.height.equalTo(6)
        }

        trailingStack.addArrangedSubview(clearTextButton)
        trailingStack.addArrangedSubview(micButton)
        trailingStack.addArrangedSubview(micIndicator)
    }

    @objc func didTapMic() {
#if targetEnvironment(simulator)
        showSpeechPermissionAlert(message: "模拟器不支持录音，请在真机测试语音输入。")
        return
#endif
        if isRecognizing {
            stopRecognitionIfNeeded()
            return
        }

        Task { @MainActor in
            let allowed = await speechManager.requestPermissions()
            guard allowed else {
                showSpeechPermissionAlert(message: "请在系统设置中允许麦克风和语音识别权限。")
                return
            }
            recognitionBaseText = input.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            startRecognition()
        }
    }

    func startRecognition() {
        isRecognizing = true
        micIndicator.isHidden = false
        micButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        micButton.tintColor = AppTheme.accent

        speechManager.startRecognition(
            baseText: recognitionBaseText,
            onUpdate: { [weak self] transcript, isFinal in
                guard let self else { return }
                let prefix = self.recognitionBaseText
                let combined: String
                if prefix.isEmpty {
                    combined = transcript
                } else if transcript.isEmpty {
                    combined = prefix
                } else {
                    combined = prefix + " " + transcript
                }
                self.input.inputText = combined
                if isFinal {
                    self.stopRecognitionIfNeeded()
                }
            },
            onError: { [weak self] _ in
                self?.stopRecognitionIfNeeded()
            }
        )
    }

    func stopRecognitionIfNeeded() {
        guard isRecognizing else { return }
        isRecognizing = false
        speechManager.stopRecognition()
        micIndicator.isHidden = true
        micButton.setImage(UIImage(systemName: "mic"), for: .normal)
        micButton.tintColor = AppTheme.textSecondary
    }

    func showSpeechPermissionAlert(message: String) {
        let alert = UIAlertController(
            title: "需要语音权限",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }
}

extension ChatInputBarViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        input.inputText = textView.text
    }
}

extension ChatInputBarViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard !results.isEmpty else { return }

        Task {
            for result in results {
                if input.remainingSelectionLimit <= 0 { break }
                let provider = result.itemProvider
                if let data = await loadImageData(provider: provider) {
                    await MainActor.run {
                        self.input.addSelectedImageData(data)
                    }
                }
            }
        }
    }
}

private extension ChatInputBarViewController {
    func loadImageData(provider: NSItemProvider) async -> Data? {
        // 1) 优先拿原始 image data（可能来自 iCloud，回调晚一点）
        if provider.hasItemConformingToTypeIdentifier("public.image") {
            if let data = await loadDataRepresentation(provider: provider, typeIdentifier: "public.image") {
                return data
            }
        }

        // 2) fallback：拿 UIImage 再编码（避免“选了但不显示”）
        if provider.canLoadObject(ofClass: UIImage.self) {
            if let image = await loadUIImage(provider: provider) {
                return image.jpegData(compressionQuality: 0.85) ?? image.pngData()
            }
        }

        return nil
    }

    func loadDataRepresentation(provider: NSItemProvider, typeIdentifier: String) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    func loadUIImage(provider: NSItemProvider) async -> UIImage? {
        await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                continuation.resume(returning: object as? UIImage)
            }
        }
    }
}

extension ChatInputBarViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        input.selectedImages.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ChatInputSelectedImageCell.reuseIdentifier,
            for: indexPath
        ) as? ChatInputSelectedImageCell else {
            return UICollectionViewCell()
        }
        let item = input.selectedImages[indexPath.item]
        cell.configure(image: item.image) { [weak self] in
            self?.input.removeSelectedImage(id: item.id)
        }
        return cell
    }
}

private final class ChatInputSelectedImageCell: UICollectionViewCell {
    static let reuseIdentifier = "ChatInputSelectedImageCell"

    private let imageView = UIImageView()
    private let removeButton = UIButton(type: .system)
    private let removeHitAreaButton = UIButton(type: .custom)
    private var onRemove: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        onRemove = nil
    }

    func configure(image: UIImage, onRemove: @escaping () -> Void) {
        imageView.image = image
        self.onRemove = onRemove
    }

    private func setup() {
        contentView.backgroundColor = .clear
        clipsToBounds = false
        contentView.clipsToBounds = false

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 10
        imageView.layer.masksToBounds = true

        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        removeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        removeButton.tintColor = .white
        removeButton.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        removeButton.layer.cornerRadius = 9
        removeButton.layer.masksToBounds = true

        contentView.addSubview(removeButton)
        removeButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(-6)
            make.trailing.equalToSuperview().offset(6)
            make.width.height.equalTo(18)
        }

        // 可点击热区：放在 cell 内，保证超出区域也能点到删除（视觉按钮仍可“飘”在外侧）
        removeHitAreaButton.backgroundColor = .clear
        removeHitAreaButton.addTarget(self, action: #selector(didTapRemove), for: .touchUpInside)
        contentView.addSubview(removeHitAreaButton)
        removeHitAreaButton.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.trailing.equalToSuperview()
            make.width.height.equalTo(32)
        }
    }

    @objc private func didTapRemove() {
        onRemove?()
    }
}
