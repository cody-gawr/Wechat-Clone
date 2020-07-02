//
//  TSChatViewController+HandleData.swift
//  TSWeChat
//
//  Created by Hilen on 1/29/16.
//  Copyright © 2016 Hilen. All rights reserved.
//

import Foundation

// MARK: - @extension TSChatViewController
extension TSChatViewController {
    /**
     发送文字
     */
    func chatSendText() {
        dispatch_async_safely_to_main_queue({[weak self] in
            guard let strongSelf = self else { return }
            guard let textView = strongSelf.chatActionBarView.inputTextView else {return }
            guard textView.text.ts_length < 1000 else {
                TSProgressHUD.ts_showWarningWithStatus("超出字数限制")
                return
            }
            
            let text = textView.text.trimmingCharacters(in: CharacterSet.whitespaces)
            if text.count == 0 {
                TSProgressHUD.ts_showWarningWithStatus("不能发送空白消息")
                return
            }
            
            let string = strongSelf.chatActionBarView.inputTextView.text
            let model = ChatModel(text: string!)
            strongSelf.itemDataSouce.append(model)
            let insertIndexPath = IndexPath(row: strongSelf.itemDataSouce.count - 1, section: 0)
            strongSelf.listTableView.insertRowsAtBottom([insertIndexPath])
            textView.text = "" //发送完毕后清空
            
            strongSelf.textViewDidChange(strongSelf.chatActionBarView.inputTextView)
        })
    }

    /**
     发送声音
     */
    func chatSendVoice(_ audioModel: ChatAudioModel) {
        dispatch_async_safely_to_main_queue({[weak self] in
            guard let strongSelf = self else { return }
            let model = ChatModel(audioModel: audioModel)
            strongSelf.itemDataSouce.append(model)
            let insertIndexPath = IndexPath(row: strongSelf.itemDataSouce.count - 1, section: 0)
            strongSelf.listTableView.insertRowsAtBottom([insertIndexPath])
        })
    }

    /**
     发送图片
     */
    func chatSendImage(_ imageModel: ChatImageModel) {
        dispatch_async_safely_to_main_queue({[weak self] in
            guard let strongSelf = self else { return }
            let model = ChatModel(imageModel:imageModel)
            strongSelf.itemDataSouce.append(model)
            let insertIndexPath = IndexPath(row: strongSelf.itemDataSouce.count - 1, section: 0)
            strongSelf.listTableView.insertRowsAtBottom([insertIndexPath])
        })
    }
}







