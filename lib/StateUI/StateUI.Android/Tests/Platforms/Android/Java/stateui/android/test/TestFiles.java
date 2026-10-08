// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android.test;

import android.content.Context;
import android.net.Uri;
import java.io.File;

/** The folder the files a test opens and saves stand in: the test application's own, emptied as each case starts. */
public final class TestFiles {
    private TestFiles() {}

    /** Empties the folder, and answers its address with a slash after it. */
    public static String emptied(Context context) {
        File folder = new File(context.getCacheDir(), "stateui-conformance-files");
        File[] files = folder.listFiles();
        if (files != null) for (File file : files) file.delete();
        folder.mkdirs();
        return Uri.fromFile(folder) + "/";
    }
}
