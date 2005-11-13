/*
 * Hedgewars, a worms-like game
 * Copyright (c) 2005 Andrey Korotaev <unC0Rr@gmail.com>
 *
 * Distributed under the terms of the BSD-modified licence:
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * with the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <QDateTime>
#include "rndstr.h"

const char * letters = "qwertyuiopasdfghjklzxcvbnm" \
                       "QWERTYUIOPASDFGHJKLZXCVBNM" \
                       "0123456789";
const quint8 letterscnt = 62;

const char * upd = "/hw!/";
const quint8 updcnt = 5;

RNDStr::RNDStr()
{
	SHA1Init(&ctx);
	QDateTime now = QDateTime::currentDateTime();
	QDateTime zero;
	int secs = now.secsTo(zero);
	SHA1Update(&ctx, (quint8 *)&secs, sizeof(int));
}
	
void RNDStr::GenRNDStr(QString & str, quint32 len)
{
	str = "";
	sha1_ctxt tmpctx;
	caddr_t digest;
	for(quint32 i = 0; i < len; i++)
	{
		SHA1Update(&ctx, (quint8 *)upd, updcnt);
		qMemCopy(&tmpctx, &ctx, sizeof(sha1_ctxt));
		SHA1Final(digest, &tmpctx);
		int index = (digest[3] + digest[11] + digest[17]) % letterscnt;
		str += letters[index];
	}
}
