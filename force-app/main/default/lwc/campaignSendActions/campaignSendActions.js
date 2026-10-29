export const SEND_ACTION = {
    BLUEWAVE_EMAIL: 'bluewaveEmail',
    JOURNEY: 'journey',
    MESSAGES: 'messages',
    RCS_ONLY: 'rcsOnly',
    SMS_ONLY: 'smsOnly'
};

export const MEMBER_TYPE = {
    LEAD: 'LEAD',
    OPPORTUNITY: 'OPPORTUNITY',
    ACCOUNT: 'ACCOUNT',
    CONTACT: 'CONTACT',
    OFFLINE_CAMPAIGN: 'OFFLINE_CAMPAIGN'
};

/**
 * Creates Campaign and Custom Campaign Member records after a successful send.
 * @param {Function} createCampaignWithMembers Apex import.
 * @param {string} campaignName User-entered campaign name.
 * @param {string} memberType MEMBER_TYPE constant.
 * @param {Array<string>} recordIds Selected record ids.
 * @param {Function} showToast Toast callback(title, message, variant).
 * @param {Function} extractError Error parser.
 * @returns {Promise<void>}
 */
export async function trackCampaignMembers(
    createCampaignWithMembers,
    campaignName,
    memberType,
    recordIds,
    showToast,
    extractError
) {
    try {
        await createCampaignWithMembers({
            campaignName,
            memberType,
            recordIds
        });
    } catch (error) {
        showToast(
            'Campaign Tracking',
            'Send succeeded but campaign record creation failed: ' + extractError(error),
            'warning'
        );
    }
}