// One auth owner per page/project. Shell, page and helper modules share refresh and session events.
import { createClient as createSDKClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';
const URL='https://iqarjivcrddcixrvqbfb.supabase.co';
let shared=null;
export function createClient(url,key,options){
 if(url!==URL)return createSDKClient(url,key,options);
 if(!shared)shared=createSDKClient(url,key,{...options,auth:{...options?.auth,persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
 return shared;
}
