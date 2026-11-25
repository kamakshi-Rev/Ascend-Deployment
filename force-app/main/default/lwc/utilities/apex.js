import auraInvoke from '@salesforce/apex/BaseController.auraInvoke';

const handleAuraInvokeResult = (result) => {
    const callResult = new Promise(
        (resolve, reject) => {
            if(result.error) {
                reject(result.error);
            }else if(result.success == false && result.message) {
                reject(result.message);
            }else {
                resolve(result)
            }
        }
    );
    return callResult;
};

class Apex {
    static invoke = async (handler, action, params = {}) => {
        const result = await auraInvoke({
            handlerName: handler,
            actionName: action,
            params: params
        });

        return handleAuraInvokeResult(result);
    };
}

export default Apex;