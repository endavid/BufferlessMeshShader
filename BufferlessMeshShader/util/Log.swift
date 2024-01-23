//
//  Log.swift
//  BufferlessMeshShader
//
//  Created by David Gavilan Ruiz on 23/01/2024.
//

import Foundation

func logDebug(_ text: String) {
    #if DEBUG
    print(text)
    #endif
}
