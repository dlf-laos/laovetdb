export type UUID = string;
export type DataClassification='PUBLIC'|'INTERNAL'|'RESTRICTED'|'CONFIDENTIAL'|'HIGHLY_CONFIDENTIAL';
export type PartyKind='PERSON'|'COMPANY';
export interface ApiMeta { requestId?:string; correlationId?:string; page?:number; pageSize?:number; total?:number }
export interface ApiResponse<T> { data:T; meta:ApiMeta }
export interface ApiError { error:{code:string;message:string;details?:unknown[];requestId?:string} }
export interface Party { id:UUID; partyKind:PartyKind; displayName?:string; status:string }
export interface Person { partyId:UUID; firstNameLo?:string;lastNameLo?:string;firstNameEn?:string;lastNameEn?:string;email?:string;phone?:string }
export interface Company { partyId:UUID;legalNameLo:string;legalNameEn?:string;enterpriseNo?:string;taxNo?:string;status:string }
export interface Facility { id:UUID;facilityNo?:string;nameLo:string;nameEn?:string;status:string }
export interface RegulatoryCase { id:UUID;caseNo:string;applicantPartyId:UUID;status:string;serviceCode?:string }
export interface Product { id:UUID;tradeName:string;genericName?:string;productType?:string;lifecycleStatus:string }
export interface Licence { id:UUID;licenseNo:string;holderPartyId?:UUID;status:string }
export interface Certificate { id:UUID;certificateNo:string;verificationToken:string;status:string }
export interface DomainEvent<T=unknown>{eventId?:UUID;eventType:string;occurredAt?:string;aggregateType:string;aggregateId:UUID;correlationId?:UUID;schemaVersion:number;data:T}
