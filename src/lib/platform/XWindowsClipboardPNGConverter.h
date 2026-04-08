/*
 * barrier -- mouse and keyboard sharing utility
 * Copyright (C) 2024 Barrier Contributors
 *
 * This package is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * found in the file LICENSE that should have accompanied this file.
 *
 * This package is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#pragma once

#include "XWindowsClipboard.h"
#include <string>

//! Convert to/from PNG image format on X11
class XWindowsClipboardPNGConverter : public IXWindowsClipboardConverter {
public:
    XWindowsClipboardPNGConverter(Display* display);
    virtual ~XWindowsClipboardPNGConverter();

    // IXWindowsClipboardConverter overrides
    virtual IClipboard::EFormat getFormat() const;
    virtual Atom getAtom() const;
    virtual int getDataSize() const;
    virtual std::string fromIClipboard(const std::string&) const;
    virtual std::string toIClipboard(const std::string&) const;

protected:
    //! Convert BMP data to PNG
    std::string convertBMPToPNG(const UInt8* bmpData, UInt32 width, UInt32 height, UInt32 depth) const;

    //! Convert PNG data to BMP (for local clipboard)
    std::string convertPNGToBMP(const std::string& pngData, UInt32& width, UInt32& height, UInt32& depth) const;

private:
    Atom m_atom;
};
