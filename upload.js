/**
 * Vercel Serverless — صلاحية رفع الملفات إلى Vercel Blob
 * المسار: POST /api/upload
 * يُستدعى من المتصفح عبر @vercel/blob/client → handleUploadUrl: '/api/upload'
 *
 * يتطلب في لوحة Vercel:
 *   Environment Variable → BLOB_READ_WRITE_TOKEN (يُنشأ من Storage → Blob)
 */
import { handleUpload } from '@vercel/blob/client';

export default async function handler(request) {
  // CORS بسيط لدعم نفس النطاق
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      },
    });
  }

  if (request.method !== 'POST') {
    return Response.json({ error: 'Method not allowed' }, { status: 405 });
  }

  try {
    const body = await request.json();

    const jsonResponse = await handleUpload({
      body,
      request,
      onBeforeGenerateToken: async (pathname, clientPayload) => {
        // يمكن لاحقًا التحقق من صلاحية الإدارة عبر clientPayload
        return {
          allowedContentTypes: [
            'image/jpeg',
            'image/png',
            'image/webp',
            'image/gif',
            'application/pdf',
            'application/msword',
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          ],
          maximumSizeInBytes: 10 * 1024 * 1024, // 10 MB
          tokenPayload: JSON.stringify({
            uploadedAt: Date.now(),
            client: clientPayload || null,
          }),
        };
      },
      onUploadCompleted: async ({ blob, tokenPayload }) => {
        console.log('[EACESU Blob] uploaded:', blob.url, tokenPayload);
      },
    });

    return Response.json(jsonResponse);
  } catch (error) {
    console.error('[EACESU Blob] error:', error);
    return Response.json(
      { error: error?.message || 'Upload failed' },
      { status: 400 }
    );
  }
}

export const config = {
  runtime: 'edge',
};
