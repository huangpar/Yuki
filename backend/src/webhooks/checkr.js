import { supabase } from '../db.js';
import { logger } from '../middleware/logger.js';
import { asyncHandler } from '../middleware/errorHandler.js';

export const handleCheckrWebhook = asyncHandler(async (req, res) => {
  const event = req.body;

  logger.info('Checkr webhook received', {
    eventId: event.id,
    eventType: event.type,
  });

  try {
    switch (event.type) {
      case 'report.completed':
        await handleReportCompleted(event.data.object);
        break;

      default:
        logger.debug(`Unhandled Checkr event type: ${event.type}`);
    }

    res.json({ received: true });
  } catch (err) {
    logger.error('Error processing Checkr webhook', {
      eventId: event.id,
      error: err.message,
    });

    // Always return 200 to prevent Checkr retry
    res.json({ received: true, error: err.message });
  }
});

async function handleReportCompleted(reportData) {
  const {
    id: reportId,
    candidate_id: candidateId,
    custom_id: providerId,
    status,
    result,
    consider_reasons: considerReasons,
    packages,
  } = reportData;

  if (!providerId) {
    logger.warn('Checkr report missing custom_id (provider_id)', { reportId });
    return;
  }

  logger.info('Background check report completed', {
    reportId,
    providerId,
    result,
  });

  // Update provider verification status
  let newStatus;
  let isVerified = false;

  if (result === 'clear') {
    newStatus = 'clear';
    isVerified = true;
  } else {
    newStatus = 'failed';
    isVerified = false;
  }

  const { error: updateError } = await supabase
    .from('provider_statuses')
    .update({
      background_check_status: newStatus,
      background_check_completed_at: new Date().toISOString(),
      is_verified_for_work: isVerified,
      background_check_details: {
        report_id: reportId,
        result,
        consider_reasons: considerReasons || [],
        packages,
      },
    })
    .eq('id', providerId);

  if (updateError) {
    throw new Error(`Failed to update provider status: ${updateError.message}`);
  }

  // Log audit event
  const { error: auditError } = await supabase
    .from('background_check_audit_log')
    .insert([
      {
        provider_id: providerId,
        event_type: 'report_received',
        event_details: {
          report_id: reportId,
          result,
          consider_reasons: considerReasons || [],
        },
      },
    ]);

  if (auditError) {
    logger.error('Failed to log audit event', { auditError });
  }

  // If adverse, create adverse action notice
  if (result === 'consider' || result === 'adverse') {
    await createAdverseActionNotice(providerId, considerReasons || []);
  }

  logger.info('Provider verification updated', {
    providerId,
    status: newStatus,
    isVerified,
  });
}

async function createAdverseActionNotice(providerId, reasons) {
  const noticeDeadline = new Date();
  noticeDeadline.setDate(noticeDeadline.getDate() + 30);

  const { error } = await supabase
    .from('adverse_actions')
    .insert([
      {
        provider_id: providerId,
        reason: reasons,
        notice_sent_at: new Date().toISOString(),
        dispute_deadline: noticeDeadline.toISOString(),
        status: 'pending_response',
      },
    ]);

  if (error) {
    logger.error('Failed to create adverse action notice', {
      providerId,
      error: error.message,
    });
    return;
  }

  logger.info('Adverse action notice created', {
    providerId,
    deadlineDate: noticeDeadline.toISOString(),
  });

  // Log audit event
  await supabase
    .from('background_check_audit_log')
    .insert([
      {
        provider_id: providerId,
        event_type: 'adverse_notice_sent',
        event_details: {
          reasons,
          deadline: noticeDeadline.toISOString(),
        },
      },
    ]);
}

export default { handleCheckrWebhook };
